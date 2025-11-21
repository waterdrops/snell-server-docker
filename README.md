<p align="center">
  <a>English</a> | <a href="https://github.com/waterdrops/snell-server/blob/main/README.zh_CN.md">中文</a>
</p>

# Snell Server Docker Image
 [![Build](https://github.com/waterdrops/snell-server-docker/actions/workflows/build-push.yml/badge.svg)](https://github.com/waterdrops/snell-server-docker/actions/workflows/build-push.yml) [![Release](https://img.shields.io/github/release/waterdrops/snell-server-docker.svg?style=flat-square&logo=github&logoColor=fff&color=005AA4)](https://github.com/waterdrops/snell-server-docker/releases) [![Image Size](https://img.shields.io/docker/image-size/1byte/snell-server?style=&logo=docker)](https://hub.docker.com/r/1byte/snell-server/) [![Docker Pulls](https://img.shields.io/docker/pulls/1byte/snell-server.svg?style=&logo=docker)](https://hub.docker.com/r/1byte/snell-server) [![Docker Stars](https://img.shields.io/docker/stars/1byte/snell-server.svg?style=flat-square&logo=docker)](https://hub.docker.com/r/1byte/snell-server/) [![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fwaterdrops%2Fsnell-server.svg?type=small)](https://app.fossa.com/projects/git%2Bgithub.com%2Fwaterdrops%2Fsnell-server?ref=badge_small) [![Repository License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](https://opensource.org/license/mit)

A lightweight, multi-architecture (`linux/amd64` and `linux/arm64`) Docker image for Snell Server.  
Supports configuration via environment variables, with secure defaults when not provided: random PSK and random port (>1024).

## Available Images

This project provides Docker images from two sources:

- **Docker Hub**: `1byte/snell-server`
- **GitHub Container Registry (GHCR)**: `ghcr.io/waterdrops/snell-server`

Both images are identical and you can use either one based on your preference.

## Features

- **Multi-stage build** for a smaller image size
- **Multi-architecture support**: `linux/amd64`, `linux/arm64`
- **Configurable via environment variables**
- **Secure defaults**: random port and random 32-character PSK
- **Minimal dependencies**: based on [frolvlad/alpine-glibc](https://github.com/Docker-Hub-frolvlad/docker-alpine-glibc) for glibc compatibility
- **Conditional configuration**: only writes optional fields when values are provided
- **Input validation**: validates IPv6 and OBFS values before startup

## Environment Variables

| Variable    | Default Value               | Description          | Validation Rules                      |
| ----------- | --------------------------- | -------------------- | ------------------------------------- |
| `PORT`      | Random 1025–65535           | Listening port       | Must be integer 1025–65535            |
| `PSK`       | Random 32-char alphanumeric | Pre-shared key       | Required                              |
| `IPv6`      | Not set (optional)          | Enable IPv6          | Must be `true` or `false` if provided |
| `OBFS`      | Not set (optional)          | Obfuscation mode     | Must be `off` or `http` if provided   |
| `OBFS_HOST` | Not set (optional)          | Obfuscation host     | Only used when `OBFS=http`            |
| `TFO`       | `true`                      | Enable TCP Fast Open | Boolean                               |

## Configuration Behavior

The server uses conditional configuration writing:

- **IPv6**: Only written to config if `IPv6` environment variable is set
- **OBFS**: Only written to config if `OBFS` environment variable is set
- **OBFS_HOST**: Only written to config if `OBFS=http` and `OBFS_HOST` is set
- **Existing config file**: If `snell-server.conf` already exists (e.g., mounted via volume), it will be used as-is and the script will skip generating a new one

## Docker Images

```bash
# Docker Hub
docker pull 1byte/snell-server

# GitHub Container Registry
docker pull ghcr.io/waterdrops/snell-server
```

## Build the Image

### Local build:

```bash
# Build with default Snell version (5.0.1)
git clone https://github.com/waterdrops/snell-server-docker.git
cd snell-server-docker
docker build -t 1byte/snell-server .

# Build with specific Snell version
docker build --build-arg SNELL_VERSION=4.1.1 -t 1byte/snell-server:4.1.1 .
```

### Multi-arch build (requires buildx):

```bash
# Build with default Snell version (5.0.1)
cd snell-server-docker # Please make sure to clone it first before proceeding
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t 1byte/snell-server:latest .

# Build with specific Snell version
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg SNELL_VERSION=4.1.1 \
  -t 1byte/snell-server:v4.1.1 .
```

## Run Examples

### Default config (random port & PSK, for testing only)

```bash
# Using Docker Hub
docker run --rm 1byte/snell-server

# Using GitHub Container Registry
docker run --rm ghcr.io/waterdrops/snell-server
```

### Specify port and PSK

```bash
# Using Docker Hub
docker run -it -p 8234:8234 \
  -e PORT=8234 \
  -e PSK=mysecurepsk \
  1byte/snell-server

# Using GitHub Container Registry
docker run -it -p 8234:8234 \
  -e PORT=8234 \
  -e PSK=mysecurepsk \
  ghcr.io/waterdrops/snell-server
```

### Complete configuration example

Please refer to the `Environment Variables` section and adjust them as needed.  For example, you can disable obfuscation by setting: `OBFS=off`

```bash
# Using Docker Hub
docker run -itd -p 8234:8234 \
  -e PORT=8234 \
  -e PSK=mysecurepsk \
  -e IPv6=true \
  -e OBFS=http \
  -e OBFS_HOST=gateway.icloud.com \
  -e TFO=false \
  1byte/snell-server

# Using GitHub Container Registry
docker run -itd -p 8234:8234 \
  -e PORT=8234 \
  -e PSK=mysecurepsk \
  -e IPv6=true \
  -e OBFS=http \
  -e OBFS_HOST=gateway.icloud.com \
  -e TFO=false \
  ghcr.io/waterdrops/snell-server
```

## Run with docker-compose

### Quick start

1. Ensure `docker-compose.yml` is in your working directory
2. Provide environment variables via a `.env` file (recommended) or your shell

#### Example `.env` and docker-compose.yml(place next to `docker-compose.yml`):

##### `.env`

```env
PORT=8234
PSK=mysecurepsk
# IPv6=false
# TFO=true
# OBFS=http
# OBFS_HOST=gateway.icloud.com
```

##### `docker-compose.yml`

```yaml
services:
  snell-server:
    container_name: snell-server
    restart: always
    image: 1byte/snell-server:latest
    ports:
      - "${PORT:-8234}:${PORT:-8234}"   # Default to 8234 if PORT is not set
    environment:
      PORT: "${PORT}"
      PSK: "${PSK}"
      # IPv6: "${IPv6}"
      # TFO: "${TFO}"
      # OBFS: "${OBFS}"        # Set to "false" to disable; `http` enables it
      # OBFS_HOST: "${OBFS_HOST}"
    # volumes:
    #   - ./snell-server.conf:/app/snell-server.conf
```


##### Use a custom snell-server.conf

If you already have a `snell-server.conf`, mount it and the script will skip auto-generation:

```yaml
services:
  snell-server:
    # ...
    volumes:
      - ./snell-server.conf:/app/snell-server.conf
```

With this volume mount, the container will use your provided config file and ignore environment variables for generation.

##### Start the service:

```bash
docker compose up -d
```

### Surge Client-Side Settings(iOS & macOS)

#### Prerequisites

- Apply for a  public IP address from your ISP
- Port mapping
- Optional: A domain and a DNS provider(e.g, Cloudflare, AliCloud).  If you are going to use a DNS provider and your IP is dynamic, I recommend ddns-go for automatic DNS updates. It's a simple and easy-to-use DDNS tool. See [3] for more details.

Add the following to your Surge configuration file (e.g, Surge.conf), and replace placeholders like `YOUR_FQDN`, `YOUR_PUBLIC_IP`,  `YOUR_DOMAIN`, `${PORT}`,  `${PSK}`,  `MyHome` and `IP-CIDR,192.168.188.0/24` with your actual values.

To learn more about `Surge Policy Groups`, see Surge Policy Group documentation[1] and Surge Manual[2]. For more information on Snell, refer to Snell knowledge[4].

```vim
[Proxy]
home = snell, YOUR_FQDN or YOUR_PUBLIC_IP, ${PORT}, psk=${PSK}, version=5, reuse=true
# If obfuscation is enabled:
# home = snell, YOUR_PUBLIC_IP or YOUR_FQDN, YOUR_PORT, psk=YOUR_PSK, version=5, obfs=http, obfs-host=YOUR_OBFS_HOST, reuse=true, tfo=true
...
[Proxy Group]
# Define a policy group named `🏠Home` of type `subnet`.  
# Behavior: If the current Wi-Fi SSID is `MyHome`, connect directly;  
# otherwise, switch to the `🏠Home` policy group.
# Please refer to [1] for more details.
🏠Home = subnet, default = home, SSID:MyHome = DIRECT
...
[Rule]
IP-CIDR,192.168.188.0/24,🏠Home,no-resolve
# Modify the following line as needed when using DNS(e.g, Cloudflare or another provider.)
OR,((DOMAIN,plex.YOUR_DOMAIN), (DOMAIN,vw.YOUR_DOMAIN), (DOMAIN,gitea.YOUR_DOMAIN), (DOMAIN,myns.YOUR_DOMAIN)),🏠Home
...
```


## Error Handling

The server validates all input values before starting:

- **Invalid PORT**: Must be an integer between 1025 and 65535
- **Invalid IPv6**: Must be `true` or `false` if provided
- **Invalid OBFS**: Must be `off` or `http` if provided

If any validation fails, the server will display an error message and exit with code 1.


[1]: https://manual.nssurge.com/policy-group/subnet.html
[2]: https://manual.nssurge.com/book/understanding-surge/cn/
[3]: https://github.com/jeessy2/ddns-go
[4]: https://kb.nssurge.com/surge-knowledge-base/release-notes/snell

## License

[LICENSE](LICENSE)

[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fwaterdrops%2Fsnell-server.svg?type=large&issueType=license)](https://app.fossa.com/projects/git%2Bgithub.com%2Fwaterdrops%2Fsnell-server?ref=badge_large&issueType=license)

