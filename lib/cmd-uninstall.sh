#!/usr/bin/env bash
# uninstall: 'uninstall' command
# Sourced by dns-sinkhole.sh, not meant to be executed directly.

do_uninstall() {
  info "Uninstalling ${PROG}"

  # 1. timer and units
  run systemctl disable --now "${PROG}-update.timer" 2>/dev/null || true
  remove_managed "$UNIT_TIMER"
  remove_managed "$UNIT_SERVICE"

  # 2. hand DNS back to the system first, so there is no outage window
  remove_managed "$RESOLVED_DROPIN"
  restore_backup "$RESOLVED_DROPIN"
  run systemctl restart systemd-resolved || true
  restore_nm_profiles

  # 3. stop dnsmasq and remove everything we created
  run systemctl disable --now dnsmasq 2>/dev/null || true
  remove_managed "$DNSMASQ_CONF"
  restore_backup "$DNSMASQ_CONF"
  remove_managed "$DNSMASQ_RESTART_DROPIN"
  run rmdir /etc/systemd/system/dnsmasq.service.d 2>/dev/null || true
  remove_managed "$BLOCKLIST_FILE"
  remove_managed "$SELFTEST_FILE"
  run rmdir "$HOSTS_DIR" 2>/dev/null || true
  [[ -e "$CUSTOM_FILE" ]] && info "Kept your own domain list: ${CUSTOM_FILE}"
  run rm -rf "$STAGING_DIR"
  run systemctl daemon-reload

  # 4. state and installed copy of this script
  run rm -rf "$STATE_DIR"

  if (( ! DRY_RUN )); then
    if resolvectl query --legend=no fedoraproject.org >/dev/null 2>&1; then
      info "DNS works. ${PROG} removed."
    else
      warn "DNS lookup failed after uninstall. Try: sudo systemctl restart NetworkManager"
    fi
  fi
  run rm -f "$INSTALLED_BIN"
  run rm -rf "$INSTALLED_LIB_DIR"
  return 0
}
