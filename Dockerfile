# ---------- Build Stage ----------
FROM debian:stable-slim AS builder

# Set build-time arguments
ARG BUILD_DIR="build"
ARG TARGETARCH
ARG TARGETOS
ARG SNELL_VERSION=6.0.0b1

WORKDIR /${BUILD_DIR}

RUN set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        libc-ares2 \
        libsodium23 \
        libuv1-dev \
        unzip && \
    rm -rf /var/lib/apt/lists/*; \
    
    # Chose the Arch type \
    case "${TARGETARCH}" in \
      amd64) SNELL_ARCH="linux-amd64" ;; \
      arm64) SNELL_ARCH="linux-aarch64" ;; \
      386)   SNELL_ARCH="linux-i386" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH} (386/amd64/arm64 only)"; exit 1 ;; \
    esac; \
    URL="https://github.com/waterdrops/snell-server-docker/releases/download/v${SNELL_VERSION}/snell-server-v${SNELL_VERSION}-${SNELL_ARCH}.zip" && \
    echo "Downloading ${URL}" && \
    wget "${URL}" -O snell.zip  && \
    unzip -q snell.zip && \
    chmod +x snell-server && \
    # Download and install the libssl1.1.deb package
    ARCH=$(dpkg --print-architecture) && \
    wget http://security.debian.org/debian-security/pool/updates/main/o/openssl/libssl1.1_1.1.1w-0+deb11u7_${ARCH}.deb && \
    dpkg -i libssl1.1_1.1.1w-0+deb11u7_${ARCH}.deb && \
    rm -f libssl1.1_1.1.1w-0+deb11u7_${ARCH}.deb && \
    # Collect required runtime libs \
    set -eux; \
    mkdir -p /runtime/lib; \
    cp -v /lib/*/libdl.so.2 /runtime/lib/; \
    cp -v /lib/*/libgcc_s.so.1 /runtime/lib/; \
    cp -v /lib/*/libcares.so.2 /runtime/lib/; \
    cp -v /lib/*/libsodium.so.23 /runtime/lib/; \
    cp -v /lib/*/libssl.so.1.1 /runtime/lib/; \
    cp -v /lib/*/libcrypto.so.1.1 /runtime/lib/; \
    cp -v /lib/*/libuv.so.1 /runtime/lib/; \
    cp -v /usr/lib/*/libstdc++.so.6* /runtime/lib/ || true

# ---------- Runtime Stage ----------
FROM busybox:stable

ARG BUILD_DIR="build"
ARG APP_USER="appuser"

ENV PORT= \
    PSK= \
    IPv6= \
    OBFS= \
    OBFS_HOST= \
    TFO= 

WORKDIR /app

# glibc / gcc runtime
COPY --from=builder /runtime/lib /lib
COPY --from=builder /${BUILD_DIR}/snell-server .
COPY ./snell.sh .

RUN adduser -D -H -s /bin/false ${APP_USER} && \
    chown -R ${APP_USER} /app && \
    chmod +x /app/snell.sh

USER ${APP_USER}

CMD ["/app/snell.sh"]
