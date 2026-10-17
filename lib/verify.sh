#!/usr/bin/env bash
# verify: checks that DNS answers as expected
# Sourced by dns-sinkhole.sh, not meant to be executed directly.

# Ask dnsmasq directly (bypassing systemd-resolved).
dnsmasq_answers() {
  local a aaaa
  a="$(dig +short +time=2 +tries=1 @127.0.0.1 "$SELFTEST_NAME" A 2>/dev/null || true)"
  aaaa="$(dig +short +time=2 +tries=1 @127.0.0.1 "$SELFTEST_NAME" AAAA 2>/dev/null || true)"
  [[ "$a" == "0.0.0.0" && "$aaaa" == "::" ]]
}

# Full path: app -> resolved -> dnsmasq, plus a real lookup to prove normal DNS works.
end_to_end_ok() {
  for _ in $(seq 1 20); do
    if resolvectl query --legend=no "$SELFTEST_NAME" 2>/dev/null | grep -q '0\.0\.0\.0' \
       && resolvectl query --legend=no fedoraproject.org >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}
