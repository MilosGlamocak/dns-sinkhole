#!/usr/bin/env bash
# preflight: environment checks before anything is changed
# Sourced by dns-sinkhole.sh, not meant to be executed directly.

# Listeners on port 53 (loopback or wildcard) that are not dnsmasq.
port53_foreign_listener() {
  ss -H -lntup 2>/dev/null | awk '
    {
      n = split($5, a, ":")
      port = a[n]
      addr = substr($5, 1, length($5) - length(port) - 1)
    }
    port == "53" && (addr == "127.0.0.1" || addr == "0.0.0.0" || addr == "*" || addr == "[::]" || addr == "[::1]") && $0 !~ /dnsmasq/ { print }
  '
}

preflight() {
  local os_id c
  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release."
  # Parse ID instead of sourcing the file: os-release defines VERSION, NAME, ...
  # which would clash with this script's own variables.
  os_id="$(sed -n 's/^ID=//p' /etc/os-release | head -n1 | tr -d '"'"'"'')"
  [[ "$os_id" == "fedora" ]] || die "Unsupported distribution '${os_id:-unknown}'. Only Fedora is supported for now."

  for c in systemctl nmcli resolvectl curl awk ss install mktemp tr; do
    command -v "$c" >/dev/null 2>&1 || die "Required command not found: ${c}"
  done

  systemctl is-active --quiet systemd-resolved || die "systemd-resolved is not running."
  systemctl is-active --quiet NetworkManager   || die "NetworkManager is not running."

  if systemctl is-active --quiet dnsmasq && ! is_managed "$DNSMASQ_CONF"; then
    die "dnsmasq is already running with a configuration this tool does not manage. Not touching it."
  fi

  local owner
  owner="$(port53_foreign_listener)"
  if [[ -n "$owner" ]]; then
    printf '%s\n' "$owner" >&2
    die "Something else is already listening on port 53 (see above)."
  fi
}
