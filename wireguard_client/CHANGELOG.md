# Changelog

## 1.0.2

- Allowed IPs inside the home network (or another network of the host) are rejected, they would cut Home Assistant off from it.
- Connection loss detection follows the keepalive setting, a large keepalive no longer shows a false "Nicht verbunden".
- Clearer message for a public VPN address.
- The sensor is reliably set to off when the app stops.

## 1.0.1

- Status no longer shows "Nicht verbunden" for the first 15 seconds after a start.
- Only private networks are accepted as allowed IPs and VPN address, the preshared key is validated.
- Runtime files live on tmpfs, a full disk can no longer take the tunnel down.
- DNS errors no longer stall the connection monitor.

## 1.0.0

- First release: WireGuard client with UI options, status page, `binary_sensor.wireguard_client` and self-enabling watchdog.
