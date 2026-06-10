#!/bin/sh
# Test fetch-usage.sh normalization against a sample API response (no network).
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
FETCH="$ROOT/plugins/claudeUsage/fetch-usage.sh"
SAMPLE="$ROOT/fixtures/oauth-usage-sample.json"
CACHE=$(mktemp)
fail() { echo "FAIL: $1"; exit 1; }

exp5=$(date -u -d '2026-06-10T11:30:00' +%s)
exp7=$(date -u -d '2026-06-16T02:00:00' +%s)

out=$(CLAUDE_USAGE_MOCK="$SAMPLE" CACHE_FILE="$CACHE" sh "$FETCH") || fail "exit $?"
[ "$out" = "$(cat "$CACHE")" ] || fail "stdout != cache contents"

jq -e '.five_hour.used_percentage == 40' "$CACHE" >/dev/null || fail "5h utilization->floor"
jq -e --argjson e "$exp5" '.five_hour.resets_at == $e' "$CACHE" >/dev/null || fail "5h iso->epoch"
jq -e '.seven_day.used_percentage == 9' "$CACHE" >/dev/null || fail "7d pct"
jq -e --argjson e "$exp7" '.seven_day.resets_at == $e' "$CACHE" >/dev/null || fail "7d iso->epoch"
jq -e '.captured_at | type == "number"' "$CACHE" >/dev/null || fail "captured_at"

# An error body (no five_hour) must fail with non-zero exit.
echo '{"error":{"type":"rate_limit_error"}}' > "$CACHE.err"
if CLAUDE_USAGE_MOCK="$CACHE.err" CACHE_FILE="$CACHE.err.out" sh "$FETCH" >/dev/null 2>&1; then
  fail "should reject error body"
fi

rm -f "$CACHE" "$CACHE.err" "$CACHE.err.out"
echo "ALL FETCH TESTS PASSED"
