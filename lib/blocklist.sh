#!/usr/bin/env bash
# blocklist: download, convert and reload
# Sourced by dns-sinkhole.sh, not meant to be executed directly.

fetch_blocklist() {
  info "Downloading blocklist from ${BLOCKLIST_URL}"
  if (( DRY_RUN )); then
    printf '[dry-run] download, convert and install %s\n' "$BLOCKLIST_FILE"
    return 0
  fi
  install -d -m 0755 "$STAGING_DIR" "$HOSTS_DIR"
  local raw="${STAGING_DIR}/blocklist.raw" out="${STAGING_DIR}/blocklist.hosts" n
  curl -fsSL --retry 3 --connect-timeout 10 --max-time 120 "$BLOCKLIST_URL" -o "$raw" \
    || die "Download failed. Existing blocklist (if any) was left untouched."
  {
    printf '%s\n' "$MARKER"
    printf '# Source: %s\n' "$BLOCKLIST_URL"
    convert_hosts <"$raw"
  } >"$out"
  n="$(grep -c '^0\.0\.0\.0 ' "$out" || true)"
  if (( n < MIN_DOMAINS )); then
    rm -f "$raw" "$out"
    die "Blocklist looks wrong (${n} domains, expected at least ${MIN_DOMAINS}). Existing blocklist left untouched."
  fi
  chmod 0644 "$out"
  mv -f "$out" "$BLOCKLIST_FILE"
  rm -f "$raw"
  relabel "$HOSTS_DIR" "$STAGING_DIR"
  info "Blocklist installed: ${n} domains"
}

reload_dnsmasq() {
  run systemctl reload dnsmasq || run systemctl restart dnsmasq
}
