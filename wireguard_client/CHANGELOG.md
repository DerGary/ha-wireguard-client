# Changelog

## 1.0.4

- VPN address and allowed IPs must not overlap a local network in either direction. A larger network like `192.168.0.0/16` is refused too, it would also catch other networks behind the router.
- Malformed networks are reported as invalid instead of "kein privates Netz".

## 1.0.3

- A VPN address whose network lies in the home network is rejected, it would cut Home Assistant off from the LAN.
- Malformed networks like `10.99.0.0./24` stop the app with a message instead of restarting it every 15 seconds.
- At boot the network check waits up to 60 seconds for the LAN to come up.
- Keepalive is limited to 1 to 120 seconds, so a lost connection is detected within about 5 minutes.

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
