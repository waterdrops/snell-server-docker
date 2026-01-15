# ---------- Build Stage ----------
FROM debian:stable-slim AS builder

# Set build-time arguments
ARG BUILD_DIR="build"
ARG TARGETARCH
ARG TARGETOS
ARG SNELL_VERSION=5.0.0

WORKDIR /${BUILD_DIR}

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        unzip \
        libstdc++6; \
    rm -rf /var/lib/apt/lists/* && \
    # Chose the Arch type
    case "${TARGETARCH}" in \
      amd64) SNELL_ARCH="linux-amd64" ;; \
      arm64) SNELL_ARCH="linux-aarch64" ;; \
      386)   SNELL_ARCH="linux-i386" ;; \
      arm)   SNELL_ARCH="linux-armv7l" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH} (amd64/arm64 only)"; exit 1 ;; \
    esac; \
    URL="https://dl.nssurge.com/snell/snell-server-v${SNELL_VERSION}-${SNELL_ARCH}.zip" && \
    echo "Downloading ${URL}" && \
    wget "${URL}" -O snell.zip  && \
    unzip -q snell.zip && \
    chmod +x snell-server && \
    # Collect required runtime libs
    set -eux; \
    mkdir -p /runtime/lib; \
    cp -v /lib/*/libdl.so.2 /runtime/lib/; \
    cp -v /lib/*/libgcc_s.so.1 /runtime/lib/; \
    cp -v /usr/lib/*/libstdc++.so.6* /runtime/lib/ || true

# ---------- Runtime Stage ----------
FROM busybox:stable

ARG BUILD_DIR="build"

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


CMD ["/bin/sh", "/app/snell.sh"]
