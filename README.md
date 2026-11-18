# WireGuard Client for Home Assistant

Home Assistant app that keeps a Home Assistant OS box connected to a WireGuard
server, e.g. so a reverse proxy on a VPS can reach it through the tunnel.

[![Add repository to my Home Assistant][repo-badge]][repo-url]

- Configured in the app UI, no files or shell needed
- Starts on boot, before Home Assistant Core
- Turns on its own watchdog; a hung app gets restarted by the Supervisor
- Re-resolves the server name when the connection drops
- Status page ("Open Web UI") and `binary_sensor.wireguard_client` for automations

See [DOCS.md](wireguard_client/DOCS.md) for setup.

## Development

- `test/e2e.sh` runs the app against a real WireGuard server container and a
  mock Supervisor (Docker with WireGuard kernel support, about 8 minutes).
- `.devcontainer.json` starts a full Supervisor + Home Assistant on
  <http://localhost:7123> with this repo as local app repository.
- Pushing to `main` builds and publishes `ghcr.io/dergary/ha-wireguard-client`
  for amd64 and aarch64. Bump `version` in `config.yaml` for every release.

[repo-badge]: https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg
[repo-url]: https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FDerGary%2Fha-wireguard-client
