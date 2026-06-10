#!/bin/sh
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
M="$ROOT/plugins/claudeUsage/plugin.json"
fail() { echo "FAIL: $1"; exit 1; }
jq -e . "$M" >/dev/null 2>&1 || fail "plugin.json is not valid JSON"
for k in id name description version author type capabilities component; do
  jq -e "has(\"$k\")" "$M" >/dev/null || fail "missing required key: $k"
done
jq -e '.id == "claudeUsage"' "$M" >/dev/null || fail "id must be claudeUsage"
jq -e '.type == "widget"' "$M" >/dev/null || fail "type must be widget"
jq -e '.component | test("^\\./.*\\.qml$")' "$M" >/dev/null || fail "component path"
jq -e '.id | test("^[a-zA-Z][a-zA-Z0-9]*$")' "$M" >/dev/null || fail "id pattern"
jq -e '.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+")' "$M" >/dev/null || fail "semver"
echo "MANIFEST OK"
