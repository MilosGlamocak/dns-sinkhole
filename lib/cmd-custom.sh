#!/usr/bin/env bash
# custom: 'add', 'remove', 'search' and 'list' commands for your own domains
# Sourced by dns-sinkhole.sh, not meant to be executed directly.
#
# Your own domains live in CUSTOM_FILE, separate from the downloaded blocklist,
# so 'update' (which only rewrites the blocklist) never touches them.
# Two kinds of rule, both answer 0.0.0.0 / ::
#   exact:      host-record=example.com,0.0.0.0,::   only that name
#   subdomains: address=/example.com/0.0.0.0 (+ ::)  the name and everything below it
# dnsmasq reads /etc/dnsmasq.d only on start, so changes need a restart.

# Domain -> "exact" | "subdomains", loaded from CUSTOM_FILE.
declare -A CUSTOM_MODE=()

# Lowercase, drop a trailing dot, validate. Prints the cleaned name or fails.
normalize_domain() {
  local d="${1,,}"
  d="${d%.}"
  [[ "$d" =~ ^[a-z0-9]([a-z0-9._-]*[a-z0-9])?$ ]] || return 1
  [[ "$d" =~ ^(localhost|localhost\.localdomain|local|broadcasthost)$ ]] && return 1
  printf '%s\n' "$d"
}

load_custom() {
  CUSTOM_MODE=()
  [[ -f "$CUSTOM_FILE" ]] || return 0
  local mode d
  while read -r mode d; do
    CUSTOM_MODE["$d"]="$mode"
  done < <(awk -F'[=,/]' '
    $1 == "host-record" && NF >= 2 { print "exact " $2 }
    $1 == "address"     && $3 != "" && $4 == "0.0.0.0" { print "subdomains " $3 }' "$CUSTOM_FILE")
}

require_installed() {
  [[ -d "$STATE_DIR" ]] || die "Not installed. Run '${PROG} install' first."
}

# write_custom - write CUSTOM_MODE to CUSTOM_FILE, sorted by domain.
write_custom() {
  local d
  {
    printf '# Your own blocked domains, managed with: %s add|remove\n' "$PROG"
    printf '# Not touched by update or uninstall.\n'
    for d in $(printf '%s\n' "${!CUSTOM_MODE[@]}" | sort); do
      if [[ "${CUSTOM_MODE[$d]}" == subdomains ]]; then
        printf 'address=/%s/0.0.0.0\naddress=/%s/::\n' "$d" "$d"
      else
        printf 'host-record=%s,0.0.0.0,::\n' "$d"
      fi
    done
  } | put_file "$CUSTOM_FILE"
  relabel /etc/dnsmasq.d
}

# Restart dnsmasq (drops its own cache) and flush systemd-resolved's cache, so
# a changed rule takes effect now and not after the old answer's TTL runs out.
# Browsers keep a separate DNS cache that cannot be flushed from here.
restart_dnsmasq() {
  run systemctl restart dnsmasq
  run resolvectl flush-caches || true
}

describe_mode() {
  [[ "$1" == subdomains ]] && printf 'and all its subdomains' || printf 'exact name only'
}

# add [--subdomains|--exact] <domain>...
# Without a flag, ask per domain when running in a terminal (default: exact).
do_add() {
  require_installed
  local forced="" arg d m ans changed=() domains=()
  for arg in "${CMD_ARGS[@]}"; do
    case "$arg" in
      -s|--subdomains) forced=subdomains ;;
      -e|--exact)      forced=exact ;;
      -*)              die "Unknown option for add: ${arg}" ;;
      *)               domains+=("$arg") ;;
    esac
  done
  (( ${#domains[@]} )) || die "Usage: ${PROG} add [--subdomains|--exact] <domain>..."

  load_custom
  for arg in "${domains[@]}"; do
    d="$(normalize_domain "$arg")" || die "Not a valid domain: ${arg}"
    m="${forced:-exact}"
    if [[ -z "$forced" && -t 0 ]]; then
      ans=""
      read -r -p "Also block all subdomains of ${d} (e.g. www.${d})? [y/N] " ans || true
      [[ "${ans,,}" == y || "${ans,,}" == yes ]] && m=subdomains
    fi
    if [[ "${CUSTOM_MODE[$d]:-}" == "$m" ]]; then
      info "${d}: already blocked ($(describe_mode "$m"))"
    else
      CUSTOM_MODE["$d"]="$m"
      changed+=("$d")
    fi
  done
  (( ${#changed[@]} )) || return 0
  write_custom
  restart_dnsmasq
  for d in "${changed[@]}"; do
    info "Blocked: ${d} ($(describe_mode "${CUSTOM_MODE[$d]}"))"
  done
}

do_remove() {
  require_installed
  (( ${#CMD_ARGS[@]} )) || die "Usage: ${PROG} remove <domain>..."
  local arg d removed=()
  load_custom
  for arg in "${CMD_ARGS[@]}"; do
    d="$(normalize_domain "$arg")" || die "Not a valid domain: ${arg}"
    if [[ -n "${CUSTOM_MODE[$d]:-}" ]]; then
      unset 'CUSTOM_MODE[$d]'
      removed+=("$d")
    elif [[ -f "$BLOCKLIST_FILE" ]] && grep -qF -- "0.0.0.0 ${d}" "$BLOCKLIST_FILE"; then
      warn "${d} is in the downloaded blocklist, not in your custom list; it cannot be removed (update would restore it)."
    else
      warn "${d}: not found"
    fi
  done
  (( ${#removed[@]} )) || return 0
  write_custom
  restart_dnsmasq
  for d in "${removed[@]}"; do
    info "Unblocked: ${d}"
  done
}

# search <term> - substring match in the custom list and the downloaded blocklist.
do_search() {
  (( ${#CMD_ARGS[@]} == 1 )) || die "Usage: ${PROG} search <text>"
  local term="${CMD_ARGS[0],,}" found=0 d
  load_custom
  for d in $(printf '%s\n' "${!CUSTOM_MODE[@]}" | sort); do
    [[ "$d" == *"$term"* ]] || continue
    printf '%-12s %s (%s)\n' "[custom]" "$d" "$(describe_mode "${CUSTOM_MODE[$d]}")"
    found=1
  done
  if [[ -f "$BLOCKLIST_FILE" ]]; then
    while IFS= read -r d; do
      printf '%-12s %s\n' "[blocklist]" "$d"
      found=1
    done < <(awk -v t="$term" '$1 == "0.0.0.0" && index($2, t) { print $2 }' "$BLOCKLIST_FILE" | head -n 100)
  fi
  (( found )) || { info "No match for '${term}'"; return 1; }
}

do_list() {
  local d
  load_custom
  for d in $(printf '%s\n' "${!CUSTOM_MODE[@]}" | sort); do
    printf '%s (%s)\n' "$d" "$(describe_mode "${CUSTOM_MODE[$d]}")"
  done
}
