#!/usr/bin/env bash
# End-to-end test against a real WireGuard server container and a mock Supervisor.
# Needs Docker and a kernel with WireGuard. Takes about 8 minutes because the
# outage detection runs on real WireGuard timings.
# Usage: test/e2e.sh
# The sh -c strings are expanded inside the container on purpose.
# shellcheck disable=SC2016
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE=local/wireguard-client
# renovate: datasource=docker depName=python
MOCK_IMAGE=python:3.13-alpine
NET=wgtest
DATA=$(mktemp -d)
trap 'docker rm -f wgclient wgserver ipblock supervisor >/dev/null 2>&1; docker network rm $NET >/dev/null 2>&1; docker run --rm --entrypoint rm -v "$DATA:/data" $IMAGE -rf /data/posted; rm -rf "$DATA"' EXIT

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; docker logs wgclient 2>&1 | tail -30; exit 1; }
status() { docker exec wgclient jq -r .state /tmp/www/status.json 2>/dev/null || echo none; }
# wait_for <seconds> <command...>
wait_for() { local t=$1; shift; for ((i = 0; i < t; i += 5)); do "$@" && return 0; sleep 5; done; return 1; }

docker buildx build -q -t $IMAGE wireguard_client >/dev/null
docker network create $NET >/dev/null
docker run -d --name supervisor --network $NET -v "$DATA:/data" -v "$PWD/test/mock_supervisor.py:/mock.py:ro" \
    $MOCK_IMAGE python -u /mock.py >/dev/null
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

# start_client <private key> [jq filter to change the options]
start_client() {
    jq -n --arg k "$1" --arg s "$server_pub" --arg p "$psk" \
        '{private_key: $k, address: "10.99.0.2", server_public_key: $s, preshared_key: $p,
          endpoint: "wgserver:51820", allowed_ips: "10.99.0.0/24", persistent_keepalive: 25} | '"${2:-.}" > "$DATA/options.json"
    # --tmpfs /tmp: the Supervisor does the same for "tmpfs: true"
    docker run -d --name wgclient --network $NET --cap-add NET_ADMIN --tmpfs /tmp -e SUPERVISOR_TOKEN=test -v "$DATA:/data" $IMAGE >/dev/null
}

# expect_stop <log message>: the app must stop with an error and log the message
expect_stop() {
    wait_for 30 sh -c '[ "$(docker inspect -f {{.State.Running}} wgclient)" = false ]' || fail "app did not stop"
    [ "$(docker inspect -f '{{.State.ExitCode}}' wgclient)" != 0 ] || fail "app exited with 0"
    docker logs wgclient 2>&1 | grep "$1" >/dev/null || fail "message not logged: $1"
    docker rm -f wgclient >/dev/null
}

# 1. Broken config stops the app with an error.
start_client "not-a-key"
expect_stop "Private Key ist ungültig"
start_client "$client_priv" '.preshared_key = "not-a-key"'
expect_stop "Preshared Key ist ungültig"
start_client "$client_priv" '.address = "203.0.113.5"'
expect_stop "203.0.113.5 ist keine private Adresse"
start_client "$client_priv" '.allowed_ips = "10.99.0.0/24, 0.0.0.0/0"'
expect_stop "0.0.0.0/0 ist kein privates Netz"
start_client "$client_priv" '.allowed_ips = "0.0.0.0/1,128.0.0.0/1"'
expect_stop "0.0.0.0/1 ist kein privates Netz"
start_client "$client_priv" '.allowed_ips = "10.99.0.0./24"'
expect_stop "10.99.0.0./24 ist kein privates Netz"
lan=$(docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' $NET)
start_client "$client_priv" ".allowed_ips = \"10.99.0.0/24,$lan\""
expect_stop "$lan liegt im lokalen Netz"
lan_address="${lan%.*}.250/${lan#*/}"
start_client "$client_priv" ".address = \"$lan_address\""
expect_stop "VPN-Adresse $lan_address liegt im lokalen Netz"
pass "broken keys and networks, public address, internet and LAN routes stop the app with message"

# 2. Client starts before the server exists (no DNS yet), then connects.
start_client "$client_priv"
sleep 20
[ "$(status)" = off ] || fail "status should be off without server, got $(status)"
start_server
wait_for 60 sh -c '[ "$(docker exec wgclient jq -r .state /tmp/www/status.json)" = on ]' || fail "did not connect"
[ "$(sensor)" = on ] || fail "sensor not on: $(sensor)"
jq -e '.watchdog == true' "$DATA/posted/addons_self_options" >/dev/null 2>&1 || fail "watchdog not enabled"
pass "connects after server shows up late, sensor on, watchdog enabled"

# 3. Traffic both ways, server to client is what Traefik uses.
docker exec wgclient ping -c1 -W2 10.99.0.1 >/dev/null || fail "client cannot reach server"
docker exec wgserver ping -c1 -W2 10.99.0.2 >/dev/null || fail "server cannot reach client"
pass "traffic both ways"

# 4. Status page and health: Supervisor/localhost only.
docker exec wgclient curl -fsS http://127.0.0.1:61820/ | grep Verbunden >/dev/null || fail "status page"
docker exec wgclient curl -fsS http://127.0.0.1:61820/cgi-bin/health | grep ok >/dev/null || fail "health"
code=$(docker exec wgserver curl -s -o /dev/null -w '%{http_code}' http://wgclient:61820/ || true)
[ "$code" = 403 ] || fail "status page reachable from other hosts: $code"
wait_for 120 sh -c '[ "$(docker inspect -f {{.State.Health.Status}} wgclient)" = healthy ]' || fail "docker healthcheck not healthy"
pass "status page, health, healthcheck, access restriction"

# 5. Interface deleted from outside is recreated.
docker exec wgclient ip link del hawg0
sleep 5
wait_for 60 docker exec wgclient ping -c1 -W2 10.99.0.1 >/dev/null || fail "no recovery after interface loss"
pass "recovers from deleted interface"

# 6. Failing status writes do not touch the tunnel.
ifindex=$(docker exec wgclient cat /sys/class/net/hawg0/ifindex)
docker exec wgclient mkdir /tmp/www/status.json.tmp /tmp/www/index.html.tmp
sleep 35
[ "$(docker exec wgclient cat /sys/class/net/hawg0/ifindex)" = "$ifindex" ] || fail "tunnel was recreated after status write errors"
docker exec wgclient ping -c1 -W2 10.99.0.1 >/dev/null || fail "tunnel down after status write errors"
docker exec wgclient rmdir /tmp/www/status.json.tmp /tmp/www/index.html.tmp
pass "failing status writes keep the tunnel"

# 7. Server outage is detected, server comes back with a new IP, client re-resolves.
old_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' wgserver)
docker rm -f wgserver >/dev/null
wait_for 300 sh -c '[ "$(docker exec wgclient jq -r .state /tmp/www/status.json)" = off ]' || fail "outage not detected"
docker exec wgclient curl -fsS http://127.0.0.1:61820/cgi-bin/health | grep ok >/dev/null || fail "health must stay ok during outage"
[ "$(sensor)" = off ] || fail "sensor not off during outage"
pass "outage detected, sensor off, health stays ok"
docker run -d --name ipblock --network $NET --entrypoint sleep $IMAGE 600 >/dev/null # takes the old IP
start_server
docker rm -f ipblock >/dev/null
new_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' wgserver)
[ "$old_ip" != "$new_ip" ] || fail "test setup: server got the same IP"
wait_for 90 sh -c '[ "$(docker exec wgclient jq -r .state /tmp/www/status.json)" = on ]' || fail "no reconnect to new server IP"
pass "reconnects to server with new IP ($old_ip -> $new_ip)"

# 8. Clean stop: exit code 0, interface gone.
docker stop wgclient >/dev/null
[ "$(docker inspect -f '{{.State.ExitCode}}' wgclient)" = 0 ] || fail "stop exit code $(docker inspect -f '{{.State.ExitCode}}' wgclient)"
[ "$(sensor)" = off ] || fail "sensor not off after stop"
pass "clean stop, sensor off"

echo "ALL PASSED"
