#!/usr/bin/env bash
# render: config file contents and blocklist conversion (pure functions)
# Sourced by dns-sinkhole.sh, not meant to be executed directly.

render_dnsmasq_conf() {
  local s
  printf '%s\n' "$MARKER"
  printf '%s\n' "listen-address=127.0.0.1"
  printf '%s\n' "bind-interfaces"
  printf '%s\n' "# Do not read /etc/resolv.conf: it points back at us (would loop)."
  printf '%s\n' "no-resolv"
  for s in $UPSTREAM_DNS; do
    printf 'server=%s\n' "$s"
  done
  printf '%s\n' "# Ignore /etc/hosts, read only our blocklists."
  printf '%s\n' "no-hosts"
  printf 'addn-hosts=%s\n' "$HOSTS_DIR"
  printf '%s\n' "cache-size=1000"
  printf '%s\n' "# Canary domain: tells Firefox not to switch to DNS-over-HTTPS on its own."
  printf '%s\n' "address=/use-application-dns.net/"
  if (( LOG_QUERIES )); then
    printf '%s\n' "log-queries"
  fi
}

render_resolved_dropin() {
  printf '%s\n' "$MARKER"
  printf '%s\n' "[Resolve]"
  printf '%s\n' "DNS=127.0.0.1"
  printf '%s\n' "Domains=~."
}

render_restart_dropin() {
  printf '%s\n' "$MARKER"
  printf '%s\n' "[Service]"
  printf '%s\n' "Restart=on-failure"
  printf '%s\n' "RestartSec=2"
  printf '%s\n' "ExecReload=/bin/kill -HUP \$MAINPID"
}

render_selftest() {
  printf '%s\n' "$MARKER"
  printf '0.0.0.0 %s\n' "$SELFTEST_NAME"
  printf ':: %s\n' "$SELFTEST_NAME"
}

render_service() {
  printf '%s\n' "$MARKER"
  printf '%s\n' "[Unit]"
  printf '%s\n' "Description=Refresh ${PROG} blocklist"
  printf '%s\n' "After=network-online.target"
  printf '%s\n' "Wants=network-online.target"
  printf '\n'
  printf '%s\n' "[Service]"
  printf '%s\n' "Type=oneshot"
  printf '%s\n' "ExecStart=${INSTALLED_BIN} update"
}

render_timer() {
  printf '%s\n' "$MARKER"
  printf '%s\n' "[Unit]"
  printf '%s\n' "Description=Daily ${PROG} blocklist refresh"
  printf '\n'
  printf '%s\n' "[Timer]"
  printf '%s\n' "OnCalendar=daily"
  printf '%s\n' "RandomizedDelaySec=1h"
  printf '%s\n' "Persistent=true"
  printf '\n'
  printf '%s\n' "[Install]"
  printf '%s\n' "WantedBy=timers.target"
}

# Read a hosts-format blocklist on stdin, print "0.0.0.0 d" and ":: d" per domain.
# Both are needed: without the IPv6 line dnsmasq forwards AAAA queries upstream
# and the real IPv6 address leaks through.
convert_hosts() {
  tr -d '\r' | awk '
    $1 == "0.0.0.0" && NF >= 2 {
      d = tolower($2)
      if (d ~ /^[a-z0-9._-]+$/ \
          && d !~ /^(0\.0\.0\.0|localhost|localhost\.localdomain|local|broadcasthost)$/ \
          && !(d in seen)) {
        seen[d] = 1
        print "0.0.0.0 " d
        print ":: " d
      }
    }'
}
