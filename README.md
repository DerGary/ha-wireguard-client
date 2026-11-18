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

- The main repo lives on Gitea (`privat/ha-wireguard-client`), where Renovate
  keeps dependencies current. A push mirror copies every branch to GitHub.
- On GitHub, CI runs the app linter, MegaLinter (`.mega-linter.yml`), the
  end-to-end test and the multi-arch build for `main` and every `renovate/*`
  branch and reports the result back to Gitea as commit status `github-ci`.
  Gitea requires that status before a pull request can merge, so Renovate
  only automerges tested updates (never majors). Every update under
  `wireguard_client/` bumps the app version.
- When `main` carries a version that is not on ghcr yet, CI builds and
  publishes `ghcr.io/dergary/ha-wireguard-client` for amd64 and aarch64.
- `test/e2e.sh` runs the app against a real WireGuard server container and a
  mock Supervisor (Docker with WireGuard kernel support, about 9 minutes).
- `.devcontainer.json` starts a full Supervisor + Home Assistant with this repo
  as local app repository.

[repo-badge]: https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg
[repo-url]: https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FDerGary%2Fha-wireguard-client
