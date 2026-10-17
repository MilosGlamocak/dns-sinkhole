#!/usr/bin/env bash
# install: 'install' command and error rollback
# Sourced by dns-sinkhole.sh, not meant to be executed directly.

# Copy the entry script and its lib/ to system paths, so the systemd timer can
# run them. Skipped when we already run from there.
install_self() {
  if [[ "$SCRIPT_PATH" != "$INSTALLED_BIN" ]]; then
    run install -m 0755 "$SCRIPT_PATH" "$INSTALLED_BIN"
  fi
  if [[ "$LIB_DIR" != "$INSTALLED_LIB_DIR" ]]; then
    run install -d -m 0755 "$INSTALLED_LIB_DIR"
    run install -m 0644 "$LIB_DIR"/*.sh "$INSTALLED_LIB_DIR"/
  fi
}

on_error() {
  local line="$1"
  trap - ERR
  warn "Unexpected error at line ${line}."
  if (( DNS_TOUCHED )); then
    warn "Rolling back to the previous configuration..."
    do_uninstall || true
  fi
  exit 1
}

do_install() {
  preflight
  trap 'on_error $LINENO' ERR

  info "Installing packages (dnsmasq, bind-utils)"
  if ! rpm -q dnsmasq bind-utils >/dev/null 2>&1; then
    run dnf -y install dnsmasq bind-utils
  fi

  run install -d -m 0755 "$STATE_DIR" "$STAGING_DIR" "$HOSTS_DIR"

  # Download first: if this fails, nothing on the system has been changed yet.
  fetch_blocklist
  render_selftest | put_file "$SELFTEST_FILE"

  snapshot_nm_profiles

  info "Configuring dnsmasq"
  DNS_TOUCHED=1
  backup_if_foreign "$DNSMASQ_CONF"
  render_dnsmasq_conf | put_file "$DNSMASQ_CONF"
  render_restart_dropin | put_file "$DNSMASQ_RESTART_DROPIN"
  relabel "$HOSTS_DIR" "$STAGING_DIR" /etc/dnsmasq.d
  run systemctl daemon-reload
  if (( ! DRY_RUN )); then
    dnsmasq --test >/dev/null 2>&1 || die "dnsmasq rejected the generated configuration (dnsmasq --test)."
  fi
  run systemctl enable dnsmasq
  run systemctl restart dnsmasq

  if (( ! DRY_RUN )); then
    sleep 1
    dnsmasq_answers || die "dnsmasq does not answer correctly on 127.0.0.1 (check: journalctl -u dnsmasq)."
    info "dnsmasq answers correctly"
  fi

  info "Pointing systemd-resolved at dnsmasq"
  backup_if_foreign "$RESOLVED_DROPIN"
  render_resolved_dropin | put_file "$RESOLVED_DROPIN"
  relabel /etc/systemd/resolved.conf.d
  run systemctl restart systemd-resolved

  apply_nm_protection

  if (( ! DRY_RUN )); then
    info "Verifying end-to-end (can take a few seconds)"
    if ! end_to_end_ok; then
      warn "End-to-end verification failed."
      trap - ERR
      do_uninstall || true
      die "Rolled back to the previous configuration. Nothing was left changed."
    fi
  fi

  info "Installing blocklist updater (daily systemd timer)"
  install_self
  render_service | put_file "$UNIT_SERVICE"
  render_timer   | put_file "$UNIT_TIMER"
  relabel "$INSTALLED_BIN" "$INSTALLED_LIB_DIR"
  run systemctl daemon-reload
  run systemctl enable --now "${PROG}-update.timer"

  trap - ERR
  DNS_TOUCHED=0
  info "Done. Check with: ${PROG} status"
}
