#!/usr/bin/env bash
# usage: help text
# Sourced by dns-sinkhole.sh, not meant to be executed directly.

usage() {
  cat <<EOF
${PROG} ${SCRIPT_VERSION} - local DNS sinkhole for Fedora (dnsmasq + systemd-resolved)

Usage: ${PROG} [--dry-run] [--log-queries] <command> [domain...]

Commands:
  install     set everything up (idempotent, rolls back automatically on failure)
  update      re-download the blocklist and reload dnsmasq
  uninstall   restore the previous configuration
  status      show current state
  add [-s|-e] D...  block your own domain(s); -s/--subdomains also blocks subdomains,
                    -e/--exact only the name (no flag: asks). Kept across 'update'
  remove D... unblock domain(s) you added with 'add'
  search TEXT find domains in your list and in the downloaded blocklist
  list        show the domains you added
  help        show this text

Options:
  --dry-run       print what would be done, change nothing
  --log-queries   enable dnsmasq query logging (journalctl -u dnsmasq -f)

Environment:
  BLOCKLIST_URL   hosts-format blocklist (default: StevenBlack unified hosts)
  UPSTREAM_DNS    space-separated upstream resolvers (default: "1.1.1.1 8.8.8.8")
EOF
}
