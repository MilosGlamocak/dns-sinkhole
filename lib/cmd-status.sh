#!/usr/bin/env bash
# status: 'status' command
# Sourced by dns-sinkhole.sh, not meant to be executed directly.

do_status() {
  local n=0 age="n/a"
  printf 'dnsmasq:           %s\n' "$(systemctl is-active dnsmasq 2>&1 || true)"
  printf 'systemd-resolved:  %s\n' "$(systemctl is-active systemd-resolved 2>&1 || true)"
  printf 'update timer:      %s\n' "$(systemctl is-active "${PROG}-update.timer" 2>&1 || true)"
  if [[ -f "$BLOCKLIST_FILE" ]]; then
    n="$(grep -c '^0\.0\.0\.0 ' "$BLOCKLIST_FILE" || true)"
    age="$(date -r "$BLOCKLIST_FILE" '+%Y-%m-%d %H:%M')"
  fi
  printf 'blocked domains:   %s (list updated: %s)\n' "$n" "$age"
  if command -v dig >/dev/null 2>&1; then
    if dnsmasq_answers; then
      printf 'dnsmasq self-test: OK (A=0.0.0.0, AAAA=::)\n'
    else
      printf 'dnsmasq self-test: FAILED\n'
    fi
  fi
  printf '\n--- resolvectl status (Global) ---\n'
  resolvectl status 2>/dev/null | sed -n '/^Global/,/^$/p'
}
