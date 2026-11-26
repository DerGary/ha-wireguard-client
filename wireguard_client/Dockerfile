# https://contributors.home-assistant.io/apps/guides/dockerfile/
ARG BUILD_FROM=ghcr.io/home-assistant/base:3.24@sha256:5021aac8a4b7f2a1397e23a9749dfe9f736463ffa471df6b200216c68d530fe6
FROM ${BUILD_FROM}

# Pinned so Renovate updates them, each update is a new app release.
# The repology repo must match the Alpine version of BUILD_FROM.
# renovate: datasource=repology depName=alpine_3_24/wireguard-tools-wg-quick versioning=loose
ARG WG_QUICK_VERSION=1.0.20260223-r0
# renovate: datasource=repology depName=alpine_3_24/iproute2 versioning=loose
ARG IPROUTE2_VERSION=7.0.0-r0
# renovate: datasource=repology depName=alpine_3_24/busybox-extras versioning=loose
ARG BUSYBOX_EXTRAS_VERSION=1.37.0-r31

RUN apk add --no-cache \
    wireguard-tools-wg-quick="${WG_QUICK_VERSION}" \
    iproute2="${IPROUTE2_VERSION}" \
    busybox-extras="${BUSYBOX_EXTRAS_VERSION}"

COPY rootfs /

# Healthy while the monitor loop keeps writing its status, see cgi-bin/health.
# With the app watchdog on, the Supervisor restarts an unhealthy app.
# exit 1: Docker documents only 0 and 1, curl ends with its own codes.
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=4 \
    CMD ["sh", "-c", "curl -fsS -o /dev/null http://127.0.0.1:61820/cgi-bin/health || exit 1"]

LABEL \
    org.opencontainers.image.title="Home Assistant App: WireGuard Client" \
    org.opencontainers.image.description="Keeps Home Assistant connected to a WireGuard server" \
    org.opencontainers.image.source="https://github.com/DerGary/ha-wireguard-client" \
    org.opencontainers.image.licenses="MIT"
