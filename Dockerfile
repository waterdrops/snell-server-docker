# ---------- Build Stage ----------
FROM alpine:3.23 AS builder

# Set build-time arguments
ARG BUILD_DIR="build"
ARG TARGETARCH
ARG TARGETOS
ARG SNELL_VERSION=5.0.0

WORKDIR /${BUILD_DIR}

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) SNELL_ARCH="linux-amd64" ;; \
      arm64) SNELL_ARCH="linux-aarch64" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH} (amd64/arm64 only)"; exit 1 ;; \
    esac; \
    URL="https://dl.nssurge.com/snell/snell-server-v${SNELL_VERSION}-${SNELL_ARCH}.zip" && \
    echo "Downloading ${URL}" && \
    wget "${URL}" -O snell.zip  && \
    unzip -q snell.zip && \
    chmod +x snell-server


# ---------- Runtime Stage ----------
FROM frolvlad/alpine-glibc

ARG BUILD_DIR="build"
ARG APP_USER="appuser"
ENV PORT= \
    PSK= \
    IPv6= \
    OBFS= \
    OBFS_HOST= \
    TFO= 

WORKDIR /app

COPY --from=builder /${BUILD_DIR}/snell-server .
COPY ./snell.sh .

RUN adduser -S -D -H -s /sbin/nologin ${APP_USER} && \
    apk add --no-cache --update libstdc++ && \
    chown -R ${APP_USER} /app

USER ${APP_USER}


CMD ["/bin/sh", "/app/snell.sh"]
