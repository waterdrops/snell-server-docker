#!/bin/sh
set -eu  # ash 没有 pipefail

BIN="${BIN:-/app/snell-server}"
CONF="${CONF:-/app/snell-server.conf}"

# --- flags (CLI overrides env) ---
DEBUG="${DEBUG:-0}"     # 0=off, 1=info, 2=verbose, 3=trace
DRY_RUN="${DRY_RUN:-0}" # 1 to skip exec and only print actions

# parse args: --debug[=N], --dry-run, --help
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --debug)   DEBUG=1 ;;
    --debug=*) DEBUG="${arg#*=}" ;;
    --help|-h)
      cat <<USAGE
Usage: $(basename "$0") [--dry-run] [--debug[=LEVEL]]
Env:
  BIN=/path/to/snell-server     (default: /app/snell-server)
  CONF=/path/to/snell.conf      (default: /app/snell-server.conf)
  DEBUG=0|1|2|3                 (default: 0)
  DRY_RUN=0|1                   (default: 0)
USAGE
      exit 0
      ;;
  esac
done

# --- logging / errors ---
_info()   { printf '%s\n' "==> $*"; }
_err()    { printf '%s\n' "ERROR: $*" >&2; }
_die()    { _err "$*"; exit 1; }
_debug()  { [ "${DEBUG:-0}" -ge 1 ] && printf '%s\n' "[D1] $*"; return 0; }
_debug2() { [ "${DEBUG:-0}" -ge 2 ] && printf '%s\n' "[D2] $*"; return 0; }
_debug3() { [ "${DEBUG:-0}" -ge 3 ] && printf '%s\n' "[D3] $*"; return 0; }

# trace when DEBUG>=3
if [ "${DEBUG:-0}" -ge 3 ]; then
  PS4='+ ${0##*/}:$LINENO: '
  set -x
fi

# --- helpers ---
random_port() {
  # 读取 2 字节随机数并转为 1025–65535
  num="$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | tr -d ' ')"
  [ -n "$num" ] || num="$$"
  echo $(( (num % 64511) + 1025 ))
}

# busybox sed：用 -r 而非 -E
_strip_comment() { sed -r 's/[[:space:]]+#.*$//'; }

# Read "key = value" (first occurrence), trim spaces, strip inline comment
_read_kv() {
  key="$1"
  [ -f "$CONF" ] || return 0
  sed -n -r "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*(.*)$/\1/p" "$CONF" \
    | _strip_comment \
    | sed -r 's/^[[:space:]]+//; s/[[:space:]]+$//' \
    | head -n1
}

# Extract port from listen = 0.0.0.0:8060 or [::]:8060
_read_port_from_listen() {
  [ -f "$CONF" ] || return 0
  line="$(_read_kv listen)"
  [ -n "${line:-}" ] || return 0
  echo "$line" | sed -n -r 's/.*:([0-9]{1,5})[[:space:]]*$/\1/p' | head -n1
}

# --- defaults (may be overridden by config/env / hydrate) ---
_gen_psk() {
  # 避免 set -e 受上游 SIGPIPE 影响；ash 无 pipefail
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 || true
}

IPv6="${IPv6:-}"                    # true|false
MODE="${MODE:-}"             # default|unshaped|unsafe-raw
OBFS="${OBFS:-}"                    # off|http
OBFS_HOST="${OBFS_HOST:-}"
TFO="${TFO:-true}"                  # true|false
LISTEN="${LISTEN:-}"
DNS_IP_PREFERENCE="${DNS_IP_PREFERENCE:-}"

# Prefer existing config: populate variables from it if present
hydrate_from_existing_conf() {
  [ -e "$CONF" ] || return 1
  _info "Using existing config: $CONF (skip generation)"
  v="$(_read_kv listen            || true)"; [ -n "${v:-}" ] && LISTEN="$v"
  v="$(_read_port_from_listen     || true)"; [ -n "${v:-}" ] && PORT="$v"
  v="$(_read_kv psk               || true)"; [ -n "${v:-}" ] && PSK="$v"
  v="$(_read_kv ipv6              || true)"; [ -n "${v:-}" ] && IPv6="$v"
  v="$(_read_kv mode              || true)"; [ -n "${v:-}" ] && MODE="$v"
  v="$(_read_kv obfs              || true)"; [ -n "${v:-}" ] && OBFS="$v"
  v="$(_read_kv obfs-host         || true)"; [ -n "${v:-}" ] && OBFS_HOST="$v"
  v="$(_read_kv tfo               || true)"; [ -n "${v:-}" ] && TFO="$v"
  v="$(_read_kv dns-ip-preference || true)"; [ -n "${v:-}" ] && DNS_IP_PREFERENCE="$v"
  return 0
}

resolve_listen() {
  if [ "${IPv6:-}" = "true" ]; then
    echo "0.0.0.0:${PORT},[::]:${PORT}"
  elif [ -n "${LISTEN:-}" ]; then
    echo "$LISTEN"
  else
    echo "0.0.0.0:${PORT}"
  fi
}

ensure() {
  # BIN sanity（dry-run 时降级为提示）
  if [ ! -x "$BIN" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      _info "BIN not executable (dry-run): $BIN"
    else
      _die "BIN not executable: $BIN"
    fi
  fi

  case "${PORT:-}" in ''|*[!0-9]*) _die "Invalid PORT: ${PORT:-<empty>} (must be 1025–65535)";; esac
  if [ "$PORT" -lt 1025 ] || [ "$PORT" -gt 65535 ]; then
    _die "PORT out of range: $PORT (must be 1025–65535)"
  fi

  if [ -n "${IPv6:-}" ] && [ "$IPv6" != "true" ] && [ "$IPv6" != "false" ]; then
    _die "Invalid IPv6: $IPv6 (must be 'true' or 'false')"
  fi
  case "${MODE:-default}" in
    default|unshaped|unsafe-raw) ;;
    *) _die "Invalid MODE: $MODE (must be 'default', 'unshaped', or 'unsafe-raw')";;
  esac
  if [ -n "${OBFS:-}" ] && [ "$OBFS" != "off" ] && [ "$OBFS" != "http" ]; then
    _die "Invalid OBFS: $OBFS (must be 'off' or 'http')"
  fi
  if [ -n "${OBFS_HOST:-}" ] && [ "${OBFS:-}" != "http" ]; then
    _info "OBFS_HOST is set but OBFS != http; ignored."
  fi
  if [ -n "${TFO:-}" ] && [ "$TFO" != "true" ] && [ "$TFO" != "false" ]; then
    _die "Invalid TFO: $TFO (must be 'true' or 'false')"
  fi
  case "${DNS_IP_PREFERENCE:-default}" in
    default|prefer-ipv4|prefer-ipv6|ipv4-only|ipv6-only) ;;
    *) _die "Invalid DNS_IP_PREFERENCE: $DNS_IP_PREFERENCE (must be default, prefer-ipv4, prefer-ipv6, ipv4-only, or ipv6-only)";;
  esac
}

write_config_if_missing() {
  if [ -e "$CONF" ]; then
    _debug "Config exists; not writing: $CONF"
    return 0
  fi
  umask 077
  _debug2 "Writing new config to $CONF"
  {
    echo "[snell-server]"
    echo "listen = ${LISTEN}"
    echo "psk = ${PSK}"
    echo "dns-ip-preference = ${DNS_IP_PREFERENCE:-default}"
    [ -n "${IPv6:-}" ] && echo "ipv6 = ${IPv6}"
    echo "mode = ${MODE:-default}"
    if [ -n "${OBFS:-}" ]; then
      echo "obfs = ${OBFS}"
      if [ "${OBFS}" = "http" ] && [ -n "${OBFS_HOST:-}" ]; then
        echo "obfs-host = ${OBFS_HOST}"
      fi
    fi
    echo "tfo = ${TFO}"
  } >"$CONF"
}

print_start_info() {
  _info "Starting Snell"
  printf 'PORT: %s\n' "$PORT"
  printf 'LISTEN: %s\n' "$LISTEN"
  printf 'PSK: %s\n' "$PSK"
  [ -n "${IPv6:-}" ] && printf 'IPv6: %s\n' "$IPv6"
  [ -n "${DNS_IP_PREFERENCE:-}" ] && printf 'DNS_IP_PREFERENCE: %s\n' "$DNS_IP_PREFERENCE"
  [ -n "${MODE:-}" ] && printf 'MODE: %s\n' "$MODE"
  [ -n "${OBFS:-}" ] && printf 'OBFS: %s\n' "$OBFS"
  if [ "${OBFS:-}" = "http" ] && [ -n "${OBFS_HOST:-}" ]; then
    printf 'OBFS_HOST: %s\n' "$OBFS_HOST"
  fi
  printf 'TFO: %s\n' "$TFO"
}

main() {
  hydrate_from_existing_conf || true
  PORT="${PORT:-$(random_port)}"
  PSK="${PSK:-$(_gen_psk)}"
  LISTEN="$(resolve_listen)"

  ensure
  write_config_if_missing
  print_start_info

  if [ "$DRY_RUN" = "1" ]; then
    _info "Dry-run: not executing snell-server"
    printf '[dry-run] %s -c %s\n' "$BIN" "$CONF"
    exit 0
  fi

  _debug2 "exec: $BIN -c $CONF"
  exec "$BIN" -c "$CONF"
}

main "$@"

