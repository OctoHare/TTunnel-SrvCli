# syntax=docker/dockerfile:1
FROM debian:bookworm-slim

ARG TT_VERSION="1.0.33"
ARG TT_CLIENT_VERSION="1.0.49"
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl tar iproute2 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "$TARGETARCH" in \
        amd64) TT_ARCH="x86_64" ;; \
        arm64) TT_ARCH="aarch64" ;; \
        *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac; \
    # 1. Скачиваем СЕРВЕР
    curl -fsSL "https://github.com/TrustTunnel/TrustTunnel/releases/download/v${TT_VERSION}/trusttunnel-v${TT_VERSION}-linux-${TT_ARCH}.tar.gz" -o /tmp/server.tar.gz; \
    mkdir -p /tmp/server; \
    tar -xzf /tmp/server.tar.gz -C /tmp/server; \
    cp /tmp/server/*/trusttunnel_endpoint /bin/ 2>/dev/null || cp /tmp/server/trusttunnel_endpoint /bin/; \
    cp /tmp/server/*/setup_wizard /bin/setup_wizard_server 2>/dev/null || cp /tmp/server/setup_wizard /bin/setup_wizard_server; \
    rm -rf /tmp/server*; \
    \
    # 2. Скачиваем КЛИЕНТ
    curl -fsSL "https://github.com/TrustTunnel/TrustTunnelClient/releases/download/v${TT_CLIENT_VERSION}/trusttunnel_client-v${TT_CLIENT_VERSION}-linux-${TT_ARCH}.tar.gz" -o /tmp/client.tar.gz || \
    curl -fsSL "https://github.com/TrustTunnel/TrustTunnelClient/releases/download/v${TT_CLIENT_VERSION}/trusttunnel_client-linux-${TT_ARCH}.tar.gz" -o /tmp/client.tar.gz; \
    mkdir -p /tmp/client; \
    tar -xzf /tmp/client.tar.gz -C /tmp/client; \
    cp /tmp/client/*/trusttunnel_client /bin/ 2>/dev/null || cp /tmp/client/trusttunnel_client /bin/; \
    cp /tmp/client/*/setup_wizard /bin/setup_wizard_client 2>/dev/null || cp /tmp/client/setup_wizard /bin/setup_wizard_client; \
    rm -rf /tmp/client*

COPY --chmod=755 /docker-entrypoint.sh /scripts/

WORKDIR /trusttunnel
VOLUME /trusttunnel

ENTRYPOINT ["/scripts/docker-entrypoint.sh"]
