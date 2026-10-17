#!/usr/bin/env bash
# network: NetworkManager profile handling
# Sourced by dns-sinkhole.sh, not meant to be executed directly.

# UUIDs of saved Wi-Fi and Ethernet profiles.
nm_profiles() {
  nmcli -t -f UUID,TYPE connection show \
    | awk -F: '$2 == "802-11-wireless" || $2 == "802-3-ethernet" { print $1 }'
}

nm_active_uuids() {
  nmcli -t -f UUID connection show --active
}

# Remember the original ignore-auto-dns values (only once, so re-running install
# never overwrites the real originals).
snapshot_nm_profiles() {
  if [[ -s "$NM_STATE" ]]; then
    return 0
  fi
  info "Saving current NetworkManager DNS settings"
  if (( DRY_RUN )); then
    printf '[dry-run] write %s\n' "$NM_STATE"
    return 0
  fi
  install -d -m 0755 "$STATE_DIR"
  local uuid v4 v6 tmp
  tmp="$(mktemp "${NM_STATE}.XXXXXX")"
  while read -r uuid; do
    [[ -n "$uuid" ]] || continue
    v4="$(nmcli -g ipv4.ignore-auto-dns connection show uuid "$uuid")"
    v6="$(nmcli -g ipv6.ignore-auto-dns connection show uuid "$uuid")"
    printf '%s %s %s\n' "$uuid" "${v4:-no}" "${v6:-no}" >>"$tmp"
  done < <(nm_profiles)
  mv -f "$tmp" "$NM_STATE"
}

# Stop profiles from using DHCP-provided DNS (it would bypass the sinkhole).
apply_nm_protection() {
  local uuid v4 v6 changed=() active u
  info "Disabling DHCP-provided DNS on saved Wi-Fi/Ethernet profiles"
  while read -r uuid; do
    [[ -n "$uuid" ]] || continue
    v4="$(nmcli -g ipv4.ignore-auto-dns connection show uuid "$uuid")"
    v6="$(nmcli -g ipv6.ignore-auto-dns connection show uuid "$uuid")"
    if [[ "$v4" != "yes" || "$v6" != "yes" ]]; then
      run nmcli connection modify uuid "$uuid" ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes
      changed+=("$uuid")
    fi
  done < <(nm_profiles)

  if (( DRY_RUN )); then
    return 0
  fi
  active="$(nm_active_uuids)"
  for u in "${changed[@]}"; do
    if grep -qx "$u" <<<"$active"; then
      info "Re-activating connection ${u} (the network drops for a few seconds)"
      nmcli connection up uuid "$u" >/dev/null
    fi
  done
}

restore_nm_profiles() {
  [[ -s "$NM_STATE" ]] || return 0
  local uuid v4 v6 active
  info "Restoring original NetworkManager DNS settings"
  if (( DRY_RUN )); then
    printf '[dry-run] restore profiles listed in %s\n' "$NM_STATE"
    return 0
  fi
  active="$(nm_active_uuids)"
  while read -r uuid v4 v6; do
    [[ -n "$uuid" ]] || continue
    if nmcli -g connection.uuid connection show uuid "$uuid" >/dev/null 2>&1; then
      nmcli connection modify uuid "$uuid" ipv4.ignore-auto-dns "$v4" ipv6.ignore-auto-dns "$v6" || true
      if grep -qx "$uuid" <<<"$active"; then
        nmcli connection up uuid "$uuid" >/dev/null || true
      fi
    fi
  done <"$NM_STATE"
  rm -f "$NM_STATE"
}
