<p align="center">
  <a href="README.md">English</a> | <a>中文</a>
</p>

# Snell Server Docker 镜像
 [![Build](https://github.com/waterdrops/snell-server-docker/actions/workflows/build-push.yml/badge.svg)](https://github.com/waterdrops/snell-server-docker/actions/workflows/build-push.yml) [![Release](https://img.shields.io/github/release/waterdrops/snell-server-docker.svg?style=flat-square&logo=github&logoColor=fff&color=005AA4)](https://github.com/waterdrops/snell-server-docker/releases) [![Image Size](https://img.shields.io/docker/image-size/1byte/snell-server?style=&logo=docker)](https://hub.docker.com/r/1byte/snell-server/) [![Docker Pulls](https://img.shields.io/docker/pulls/1byte/snell-server.svg?style=&logo=docker)](https://hub.docker.com/r/1byte/snell-server) [![Docker Stars](https://img.shields.io/docker/stars/1byte/snell-server.svg?style=flat-square&logo=docker)](https://hub.docker.com/r/1byte/snell-server/) [![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fwaterdrops%2Fsnell-server.svg?type=small)](https://app.fossa.com/projects/git%2Bgithub.com%2Fwaterdrops%2Fsnell-server?ref=badge_small) [![Repository License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](https://opensource.org/license/mit)

一个轻量级的、支持多架构（`linux/amd64` 和 `linux/arm64`）的 Snell Server Docker 镜像。

## 为什么需要它

本项目提供开箱即用、默认安全的最小镜像，可自动生成有效配置（或复用现有配置），并在多架构环境下统一体验，让你从"可用"到"上线"只需几秒。


## 可用镜像

本项目提供两个来源的 Docker 镜像：

- **Docker Hub**: `1byte/snell-server`
- **GitHub Container Registry (GHCR)**: `ghcr.io/waterdrops/snell-server`

两个镜像完全相同，您可以根据偏好选择使用其中一个。

## 特性

- **多阶段构建** 以获得更小的镜像大小
- **多架构支持**：`linux/amd64`、`linux/arm64`
- **可通过环境变量配置**
- **安全默认值**：随机端口和随机 32 字符 PSK
- **最小依赖**：基于 [frolvlad/alpine-glibc](https://github.com/Docker-Hub-frolvlad/docker-alpine-glibc)，提供 glibc 兼容性
- **条件配置**：仅在提供值时写入可选字段
- **输入验证**：在启动前验证 IPv6 和 OBFS 值

## 贡献

欢迎任何形式的贡献！如果你有改进建议、问题报告或新特性想法：

- 先开一个 Issue 讨论你的提议
- 提交聚焦的 PR
- 可从 "good first issue" 与 "help wanted" 标签的问题着手

提交代码的同时，也请同步更新相关文档与示例。

## 支持与响应

如有问题，欢迎开 Issue。我会尽量保持响应，尤其欢迎首次贡献者。即使只是反馈和建议，也非常有价值。

## 环境变量

| 变量        | 默认值                     | 描述          | 验证规则                      |
| ----------- | --------------------------- | ------------- | ----------------------------- |
| `PORT`      | 随机 1025–65535            | 监听端口      | 必须是 1025–65535 之间的整数  |
| `PSK`       | 随机 32 字符字母数字        | 预共享密钥    | 必需                          |
| `IPv6`      | 未设置（可选）              | 启用 IPv6     | 如果提供，必须是 `true` 或 `false` |
| `OBFS`      | 未设置（可选）              | 混淆模式      | 如果提供，必须是 `off` 或 `http` |
| `OBFS_HOST` | 未设置（可选）              | 混淆主机      | 仅在 `OBFS=http` 时使用       |
| `TFO`       | `true`                      | 启用 TCP Fast Open | 布尔值                    |

## 配置行为

服务器使用条件配置写入：

- **IPv6**：仅在设置 `IPv6` 环境变量时写入配置
- **OBFS**：仅在设置 `OBFS` 环境变量时写入配置
- **OBFS_HOST**：仅在 `OBFS=http` 且设置 `OBFS_HOST` 时写入配置
- **已有配置文件**：如果已经存在 `snell-server.conf`（例如通过 volume 挂载），脚本将直接使用该文件并跳过生成

## Docker 镜像

```bash
# Docker Hub
docker pull 1byte/snell-server

# GitHub Container Registry
docker pull ghcr.io/waterdrops/snell-server
```

## 构建镜像

### 本地构建：

```bash
# 使用默认 Snell 版本构建（5.0.1）
git clone https://github.com/waterdrops/snell-server-docker.git
cd snell-server-docker
docker build -t 1byte/snell-server .

# 使用指定 Snell 版本构建
docker build --build-arg SNELL_VERSION=4.1.1 -t 1byte/snell-server:4.1.1 .
```

### 多架构构建（需要 buildx）：

```bash
# 使用默认 Snell 版本构建（5.0.1）
cd snell-server-docker # 请确保先克隆仓库
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t 1byte/snell-server:latest .

# 使用指定 Snell 版本构建
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg SNELL_VERSION=4.1.1 \
  -t 1byte/snell-server:v4.1.1 .
```

## 运行示例

### 默认配置（随机端口和 PSK，仅用于测试）

```bash
# 使用 Docker Hub
docker run --rm 1byte/snell-server

# 使用 GitHub Container Registry
docker run --rm ghcr.io/waterdrops/snell-server
```

### 指定端口和 PSK

```bash
# 使用 Docker Hub
docker run -itd -p 8234:8234 \
  -e PORT=8234 \
  -e PSK=mysecurepsk \
  1byte/snell-server

# 使用 GitHub Container Registry
docker run -itd -p 8234:8234 \
  -e PORT=8234 \
  -e PSK=mysecurepsk \
  ghcr.io/waterdrops/snell-server
```

### 完整配置示例

请参考 `环境变量` 部分并根据需要调整。例如，可以通过设置 `OBFS=off` 来禁用混淆。

```bash
# 使用 Docker Hub
docker run -itd -p 8234:8234 \
  -e PORT=8234 \
  -e PSK=mysecurepsk \
  -e IPv6=true \
  -e OBFS=http \
  -e OBFS_HOST=gateway.icloud.com \
  -e TFO=false \
  1byte/snell-server

# 使用 GitHub Container Registry
docker run -itd -p 8234:8234 \
  -e PORT=8234 \
  -e PSK=mysecurepsk \
  -e IPv6=true \
  -e OBFS=http \
  -e OBFS_HOST=gateway.icloud.com \
  -e TFO=false \
  ghcr.io/waterdrops/snell-server
```

## 使用 docker-compose 运行

### 快速开始

1. 确保 `docker-compose.yml` 位于当前工作目录
2. 通过 `.env` 文件（推荐）或 Shell 提供环境变量

#### 示例 `.env` 和 docker-compose.yml（与 `docker-compose.yml` 同目录）：

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
      - "${PORT:-8234}:${PORT:-8234}"   # 如果未设置 PORT，默认为 8234
    environment:
      PORT: "${PORT}"
      PSK: "${PSK}"
      # IPv6: "${IPv6}"
      # TFO: "${TFO}"
      # OBFS: "${OBFS}"        # 设置为 "false" 禁用；`http` 启用
      # OBFS_HOST: "${OBFS_HOST}"
    # volumes:
    #   - ./snell-server.conf:/app/snell-server.conf
```


##### 使用自定义 snell-server.conf

如果你已经有 `snell-server.conf`，可通过挂载使用，脚本会跳过自动生成：

```yaml
services:
  snell-server:
    # ...
    volumes:
      - ./snell-server.conf:/app/snell-server.conf
```

启用该挂载后，容器将使用你提供的配置文件，环境变量将不再用于生成配置。

##### 启动服务：

```bash
docker compose up -d
```

### Surge 客户端设置（iOS & macOS）

#### 前置要求

- 向 ISP 申请公网 IP 地址
- 端口映射
- 可选：域名和 DNS 提供商（如 Cloudflare、阿里云）。如果你的 IP 是动态的，建议使用 ddns-go 进行自动 DNS 更新。这是一个简单易用的 DDNS 工具。详见 [^3]。

把下面内容添加到Surge配置文件中，并将`YOUR_FQDN`、`YOUR_PUBLIC_IP`、`YOUR_DOMAIN`、`${PORT}`、`${PSK}`、`MyHome` 和 `IP-CIDR,192.168.188.0/24` 替换为你的实际值。

要了解更多关于 `Surge 策略组` 的信息，请参阅 Surge 策略组文档[^1] 和 Surge 手册[^2]。有关 Snell 的更多信息，请参考 Snell 知识库[^4]。

```vim
[Proxy]
home = snell, YOUR_FQDN or YOUR_PUBLIC_IP, ${PORT}, psk=${PSK}, version=5, reuse=true
# 如果启用了混淆 
# home = snell, YOUR_PUBLIC_IP or YOUR_FQDN, YOUR_PORT, psk=YOUR_PSK, version=5, obfs=http, obfs-host=YOUR_OBFS_HOST, reuse=true, tfo=true
...
[Proxy Group]
# 定义一个名为 `🏠Home` 的 `subnet` 类型策略组。
# 如果当前 Wi-Fi SSID 是 `MyHome`，则直连；
# 否则切换到 `🏠Home` 策略组。
# 更多详情请参考 [^1]。
🏠Home = subnet, default = home, SSID:MyHome = DIRECT
...
[Rule]
IP-CIDR,192.168.188.0/24,🏠Home,no-resolve
# 使用 DNS（如 Cloudflare 或其他提供商）时，根据需要修改以下行。
OR,((DOMAIN,plex.YOUR_DOMAIN), (DOMAIN,vw.YOUR_DOMAIN), (DOMAIN,gitea.YOUR_DOMAIN), (DOMAIN,myns.YOUR_DOMAIN)),🏠Home
...
```

## 错误处理

服务器在启动前验证所有输入值：

- **无效的 PORT**：必须是 1025 到 65535 之间的整数
- **无效的 IPv6**：如果提供，必须是 `true` 或 `false`
- **无效的 OBFS**：如果提供，必须是 `off` 或 `http`

如果任何验证失败，服务器将显示错误消息并以代码 1 退出。


[^1]: https://manual.nssurge.com/policy-group/subnet.html
[^2]: https://manual.nssurge.com/book/understanding-surge/cn/
[^3]: https://github.com/jeessy2/ddns-go
[^4]: https://kb.nssurge.com/surge-knowledge-base/release-notes/snell

## 许可证

[LICENSE](LICENSE)

[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fwaterdrops%2Fsnell-server.svg?type=large&issueType=license)](https://app.fossa.com/projects/git%2Bgithub.com%2Fwaterdrops%2Fsnell-server?ref=badge_large&issueType=license)
