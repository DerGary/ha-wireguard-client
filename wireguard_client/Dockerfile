# https://contributors.home-assistant.io/apps/guides/dockerfile/
ARG BUILD_FROM=ghcr.io/home-assistant/base:3.24@sha256:58422480a299b16b6ea376c2167463206d430619ed02b40cd687c8bd6875519e
FROM ${BUILD_FROM}

RUN apk add --no-cache wireguard-tools-wg-quick iproute2 busybox-extras

COPY rootfs /

# Healthy while the monitor loop keeps writing its status, see cgi-bin/health.
# With the app watchdog on, the Supervisor restarts an unhealthy app.
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=4 \
    CMD curl -fsS -o /dev/null http://127.0.0.1:61820/cgi-bin/health || exit 1

LABEL \
    org.opencontainers.image.title="Home Assistant App: WireGuard Client" \
    org.opencontainers.image.description="Keeps Home Assistant connected to a WireGuard server" \
    org.opencontainers.image.source="https://github.com/DerGary/ha-wireguard-client" \
    org.opencontainers.image.licenses="MIT"
