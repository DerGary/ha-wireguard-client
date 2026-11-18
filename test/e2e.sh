#!/usr/bin/env bash
# End-to-end test against a real WireGuard server container and a mock Supervisor.
# Needs Docker and a kernel with WireGuard. Takes about 8 minutes because the
# outage detection runs on real WireGuard timings.
# Usage: test/e2e.sh
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE=local/wireguard-client
NET=wgtest
DATA=$(mktemp -d)
trap 'docker rm -f wgclient wgserver ipblock supervisor >/dev/null 2>&1; docker network rm $NET >/dev/null 2>&1; docker run --rm -v "$DATA:/data" alpine:3.22 rm -rf /data/posted; rm -rf "$DATA"' EXIT

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; docker logs wgclient 2>&1 | tail -30; exit 1; }
status() { docker exec wgclient jq -r .state /var/www/status.json 2>/dev/null || echo none; }
# wait_for <seconds> <command...>
wait_for() { local t=$1; shift; for ((i = 0; i < t; i += 5)); do "$@" && return 0; sleep 5; done; return 1; }

docker buildx build -q -t $IMAGE wireguard_client >/dev/null
docker network create $NET >/dev/null
docker run -d --name supervisor --network $NET -v "$DATA:/data" -v "$PWD/test/mock_supervisor.py:/mock.py:ro" \
    python:3.13-alpine python -u /mock.py >/dev/null
sensor() { jq -r .state "$DATA/posted/core_api_states_binary_sensor.wireguard_client" 2>/dev/null || echo none; }

keys() { docker run --rm --entrypoint sh $IMAGE -c 'k=$(wg genkey); echo "$k $(echo "$k" | wg pubkey)"'; }
read -r server_priv server_pub < <(keys)
read -r client_priv client_pub < <(keys)
psk=$(docker run --rm --entrypoint wg $IMAGE genpsk)

start_server() {
    docker run -d --name wgserver --network $NET --cap-add NET_ADMIN --entrypoint sh $IMAGE -c "
        ip link add wg0 type wireguard && ip addr add 10.99.0.1/24 dev wg0
        echo $server_priv > /k; echo $psk > /p
        wg set wg0 listen-port 51820 private-key /k peer $client_pub preshared-key /p allowed-ips 10.99.0.2/32
        ip link set wg0 up && exec sleep infinity" >/dev/null
}

start_client() {
    jq -n --arg k "$1" --arg s "$server_pub" --arg p "$psk" \
        '{private_key: $k, address: "10.99.0.2", server_public_key: $s, preshared_key: $p,
          endpoint: "wgserver:51820", allowed_ips: "10.99.0.0/24", persistent_keepalive: 25}' > "$DATA/options.json"
    docker run -d --name wgclient --network $NET --cap-add NET_ADMIN -e SUPERVISOR_TOKEN=test -v "$DATA:/data" $IMAGE >/dev/null
}

# 1. Broken key stops the app with an error.
start_client "not-a-key"
wait_for 30 sh -c '[ "$(docker inspect -f {{.State.Running}} wgclient)" = false ]' || fail "bad key did not stop the app"
[ "$(docker inspect -f '{{.State.ExitCode}}' wgclient)" != 0 ] || fail "bad key exited with 0"
docker logs wgclient 2>&1 | grep -q "Private Key ist ungültig" || fail "bad key error not logged"
docker rm -f wgclient >/dev/null
pass "broken key stops app with message"

# 2. Client starts before the server exists (no DNS yet), then connects.
start_client "$client_priv"
sleep 20
[ "$(status)" = off ] || fail "status should be off without server, got $(status)"
start_server
wait_for 60 sh -c '[ "$(docker exec wgclient jq -r .state /var/www/status.json)" = on ]' || fail "did not connect"
[ "$(sensor)" = on ] || fail "sensor not on: $(sensor)"
[ -f "$DATA/posted/addons_self_options" ] && jq -e '.watchdog == true' "$DATA/posted/addons_self_options" >/dev/null || fail "watchdog not enabled"
pass "connects after server shows up late, sensor on, watchdog enabled"

# 3. Traffic both ways, server to client is what Traefik uses.
docker exec wgclient ping -c1 -W2 10.99.0.1 >/dev/null || fail "client cannot reach server"
docker exec wgserver ping -c1 -W2 10.99.0.2 >/dev/null || fail "server cannot reach client"
pass "traffic both ways"

# 4. Status page and health: Supervisor/localhost only.
docker exec wgclient curl -fsS http://127.0.0.1:61820/ | grep -q Verbunden || fail "status page"
docker exec wgclient curl -fsS http://127.0.0.1:61820/cgi-bin/health | grep -q ok || fail "health"
code=$(docker exec wgserver curl -s -o /dev/null -w '%{http_code}' http://wgclient:61820/ || true)
[ "$code" = 403 ] || fail "status page reachable from other hosts: $code"
wait_for 120 sh -c '[ "$(docker inspect -f {{.State.Health.Status}} wgclient)" = healthy ]' || fail "docker healthcheck not healthy"
pass "status page, health, healthcheck, access restriction"

# 5. Interface deleted from outside is recreated.
docker exec wgclient ip link del hawg0
wait_for 60 sh -c '[ "$(docker exec wgclient jq -r .state /var/www/status.json)" = on ]' || fail "no recovery after interface loss"
pass "recovers from deleted interface"

# 6. Server outage is detected, server comes back with a new IP, client re-resolves.
old_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' wgserver)
docker rm -f wgserver >/dev/null
wait_for 240 sh -c '[ "$(docker exec wgclient jq -r .state /var/www/status.json)" = off ]' || fail "outage not detected"
docker exec wgclient curl -fsS http://127.0.0.1:61820/cgi-bin/health | grep -q ok || fail "health must stay ok during outage"
[ "$(sensor)" = off ] || fail "sensor not off during outage"
pass "outage detected, sensor off, health stays ok"
docker run -d --name ipblock --network $NET alpine:3.22 sleep 600 >/dev/null # takes the old IP
start_server
docker rm -f ipblock >/dev/null
new_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' wgserver)
[ "$old_ip" != "$new_ip" ] || fail "test setup: server got the same IP"
wait_for 90 sh -c '[ "$(docker exec wgclient jq -r .state /var/www/status.json)" = on ]' || fail "no reconnect to new server IP"
pass "reconnects to server with new IP ($old_ip -> $new_ip)"

# 7. Clean stop: exit code 0, interface gone.
docker stop wgclient >/dev/null
[ "$(docker inspect -f '{{.State.ExitCode}}' wgclient)" = 0 ] || fail "stop exit code $(docker inspect -f '{{.State.ExitCode}}' wgclient)"
[ "$(sensor)" = off ] || fail "sensor not off after stop"
pass "clean stop, sensor off"

echo "ALL PASSED"
