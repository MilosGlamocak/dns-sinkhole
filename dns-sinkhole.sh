#!/usr/bin/env bash
#
# dns-sinkhole - local DNS ad/tracker blocking for Fedora
#
# dnsmasq answers blocked domains with 0.0.0.0 / ::, systemd-resolved stays the
# system resolver and simply forwards everything to dnsmasq.
#
#   app -> systemd-resolved (127.0.0.53) -> dnsmasq (127.0.0.1) -> upstream DNS
#
# Usage: dns-sinkhole [--dry-run] [--log-queries] <install|update|uninstall|status>
#
# This file is only the entry point (argument parsing, sudo, dispatch).
# The actual logic lives in lib/, one module per topic.

set -Eeuo pipefail

ORIG_ARGS=("$@")
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"

# Run from a checkout: lib/ sits next to this file. Run as the installed copy
# in /usr/local/sbin: lib/ was copied to /usr/local/lib/dns-sinkhole.
if [[ -f "$(dirname "$SCRIPT_PATH")/lib/common.sh" ]]; then
  LIB_DIR="$(dirname "$SCRIPT_PATH")/lib"
else
  LIB_DIR="/usr/local/lib/dns-sinkhole"
fi

# Order matters: config and common first, the rest only define functions.
for module in config common render preflight network blocklist verify \
              cmd-install cmd-update cmd-uninstall cmd-status usage; do
  [[ -r "${LIB_DIR}/${module}.sh" ]] || {
    printf 'ERROR: missing module %s/%s.sh\n' "$LIB_DIR" "$module" >&2
    exit 1
  }
  # shellcheck source=/dev/null
  source "${LIB_DIR}/${module}.sh"
done

main() {
  local cmd=""
  while (( $# )); do
    case "$1" in
      --dry-run)     DRY_RUN=1 ;;
      --log-queries) LOG_QUERIES=1 ;;
      -h|--help|help) usage; exit 0 ;;
      install|update|uninstall|status) cmd="$1" ;;
      *) usage >&2; die "Unknown argument: $1" ;;
    esac
    shift
  done
  [[ -n "$cmd" ]] || { usage >&2; exit 2; }

  if [[ "$cmd" != "status" && $EUID -ne 0 ]]; then
    info "Root privileges required, re-running with sudo"
    exec sudo env "BLOCKLIST_URL=${BLOCKLIST_URL}" "UPSTREAM_DNS=${UPSTREAM_DNS}" \
      bash "$SCRIPT_PATH" "${ORIG_ARGS[@]}"
  fi

  case "$cmd" in
    install)   do_install ;;
    update)    do_update ;;
    uninstall) do_uninstall ;;
    status)    do_status ;;
  esac
}

# Allow sourcing for tests; run only when executed directly.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
