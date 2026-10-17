#!/usr/bin/env bash
# common: logging, dry-run aware helpers, managed-file bookkeeping
# Sourced by dns-sinkhole.sh, not meant to be executed directly.

info() { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Run a command, or only print it in --dry-run mode.
run() {
  if (( DRY_RUN )); then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

# put_file DEST [MODE] - write stdin to DEST atomically (temp file in the same
# directory, so SELinux labels follow the destination directory).
put_file() {
  local dest="$1" mode="${2:-0644}" tmp
  if (( DRY_RUN )); then
    printf '[dry-run] write %s\n' "$dest"
    cat >/dev/null
    return 0
  fi
  install -d -m 0755 "$(dirname "$dest")"
  tmp="$(mktemp "${dest}.XXXXXX")"
  cat >"$tmp"
  chmod "$mode" "$tmp"
  mv -f "$tmp" "$dest"
}

relabel() {
  if command -v restorecon >/dev/null 2>&1; then
    restorecon -R "$@" >/dev/null 2>&1 || true
  fi
  return 0
}

is_managed() {
  [[ -e "$1" ]] && grep -qF "$MARKER" "$1" 2>/dev/null
}

backup_path() {
  printf '%s/%s' "$BACKUP_DIR" "$(printf '%s' "$1" | tr '/' '_')"
}

# If a file exists that we did not create, keep a copy so uninstall can restore it.
backup_if_foreign() {
  local f="$1"
  if [[ -e "$f" ]] && ! is_managed "$f"; then
    info "Backing up existing ${f}"
    run install -d -m 0700 "$BACKUP_DIR"
    run cp -a "$f" "$(backup_path "$f")"
  fi
  return 0
}

restore_backup() {
  local f="$1" b
  b="$(backup_path "$f")"
  if [[ -e "$b" ]]; then
    info "Restoring original ${f}"
    run cp -a "$b" "$f"
  fi
  return 0
}

remove_managed() {
  local f="$1"
  if [[ -e "$f" ]]; then
    if is_managed "$f"; then
      run rm -f "$f"
    else
      warn "${f} is not managed by ${PROG}; leaving it in place"
    fi
  fi
  return 0
}
