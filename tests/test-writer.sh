#!/bin/sh
# Test claude-usage-writer.sh against fixtures. Exit non-zero on any failure.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WRITER="$ROOT/writer/claude-usage-writer.sh"
TMPCACHE=$(mktemp)
fail() { echo "FAIL: $1"; exit 1; }

# Case 1: normal payload -> cache has captured_at + both blocks, epoch resets preserved
XDG_CACHE_HOME=$(dirname "$TMPCACHE") CACHE_FILE="$TMPCACHE" \
  sh "$WRITER" < "$ROOT/fixtures/stdin-normal.json" >/dev/null
jq -e '.five_hour.used_percentage == 15' "$TMPCACHE" >/dev/null || fail "5h pct"
jq -e '.five_hour.resets_at == 1781091000' "$TMPCACHE" >/dev/null || fail "5h reset epoch"
jq -e '.seven_day.used_percentage == 4' "$TMPCACHE" >/dev/null || fail "7d pct"
jq -e '.captured_at | type == "number"' "$TMPCACHE" >/dev/null || fail "captured_at"

# Case 2: ISO resets -> normalized to epoch; sonnet block present
XDG_CACHE_HOME=$(dirname "$TMPCACHE") CACHE_FILE="$TMPCACHE" \
  sh "$WRITER" < "$ROOT/fixtures/stdin-iso-resets.json" >/dev/null
jq -e '.five_hour.resets_at == 1781114400' "$TMPCACHE" >/dev/null || fail "iso->epoch (2026-06-10T18:00Z)"
jq -e '.seven_day_sonnet.used_percentage == 51' "$TMPCACHE" >/dev/null || fail "sonnet block"

# Case 3: no rate_limits -> cache left UNCHANGED (still case-2 content)
XDG_CACHE_HOME=$(dirname "$TMPCACHE") CACHE_FILE="$TMPCACHE" \
  sh "$WRITER" < "$ROOT/fixtures/stdin-no-ratelimits.json" >/dev/null
jq -e '.seven_day_sonnet.used_percentage == 51' "$TMPCACHE" >/dev/null || fail "cache should be untouched when no rate_limits"

# Case 4: passthrough -> wrapped command receives stdin and its stdout is printed
OUT=$(XDG_CACHE_HOME=$(dirname "$TMPCACHE") CACHE_FILE="$TMPCACHE" \
  sh "$WRITER" cat < "$ROOT/fixtures/stdin-normal.json")
echo "$OUT" | jq -e '.rate_limits.five_hour.used_percentage == 15' >/dev/null || fail "passthrough stdin"

rm -f "$TMPCACHE"
echo "ALL WRITER TESTS PASSED"
