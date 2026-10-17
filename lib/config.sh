#!/usr/bin/env bash
# config: constants, paths and user-tunable defaults
# Sourced by dns-sinkhole.sh, not meant to be executed directly.

readonly SCRIPT_VERSION="0.1.0"
readonly PROG="dns-sinkhole"
readonly MARKER="# Managed by ${PROG} - do not edit by hand (run '${PROG} uninstall' to remove)"

readonly DNSMASQ_CONF="/etc/dnsmasq.d/sinkhole.conf"
readonly DNSMASQ_RESTART_DROPIN="/etc/systemd/system/dnsmasq.service.d/90-${PROG}-restart.conf"
readonly RESOLVED_DROPIN="/etc/systemd/resolved.conf.d/90-local-dns.conf"
readonly HOSTS_DIR="/etc/hosts.d"
readonly BLOCKLIST_FILE="${HOSTS_DIR}/stevenblack"
readonly SELFTEST_FILE="${HOSTS_DIR}/00-${PROG}-selftest"
readonly SELFTEST_NAME="selftest.${PROG}.example.net"
readonly STAGING_DIR="/etc/${PROG}"
readonly STATE_DIR="/var/lib/${PROG}"
readonly NM_STATE="${STATE_DIR}/nm-profiles"
readonly BACKUP_DIR="${STATE_DIR}/backup"
readonly INSTALLED_BIN="/usr/local/sbin/${PROG}"
readonly UNIT_SERVICE="/etc/systemd/system/${PROG}-update.service"
readonly UNIT_TIMER="/etc/systemd/system/${PROG}-update.timer"
readonly INSTALLED_LIB_DIR="/usr/local/lib/${PROG}"

BLOCKLIST_URL="${BLOCKLIST_URL:-https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts}"
UPSTREAM_DNS="${UPSTREAM_DNS:-1.1.1.1 8.8.8.8}"
MIN_DOMAINS=1000

DRY_RUN=0
LOG_QUERIES=0
DNS_TOUCHED=0
