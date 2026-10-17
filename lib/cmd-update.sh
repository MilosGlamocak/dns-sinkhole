#!/usr/bin/env bash
# update: 'update' command
# Sourced by dns-sinkhole.sh, not meant to be executed directly.

do_update() {
  [[ -d "$STATE_DIR" ]] || die "Not installed. Run '${PROG} install' first."
  fetch_blocklist
  reload_dnsmasq
  if (( ! DRY_RUN )); then
    sleep 1
    dnsmasq_answers || warn "dnsmasq self-test failed after update (check: journalctl -u dnsmasq)."
  fi
  info "Update finished."
}
