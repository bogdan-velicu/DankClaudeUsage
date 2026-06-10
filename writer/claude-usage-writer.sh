#!/bin/sh
# claude-usage-writer.sh
# Reads Claude Code statusline JSON on stdin, writes the usage cache atomically,
# and (if extra args are given) execs them as a wrapped statusline command with
# the same stdin so this can chain into an existing statusline.
#
# Cache path: $CACHE_FILE, else $XDG_CACHE_HOME/dms-claude-usage.json,
# else $HOME/.cache/dms-claude-usage.json
set -u
input=$(cat)
cache="${CACHE_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/dms-claude-usage.json}"
mkdir -p "$(dirname "$cache")" 2>/dev/null
now=$(date +%s)
tmp="$cache.tmp.$$"

printf '%s' "$input" | jq --argjson now "$now" '
  def toepoch(s):
    s | gsub("\\+00:00$"; "Z") | gsub("\\+0000$"; "Z") | fromdateiso8601;
  def norm(b):
    if b == null then null
    else { used_percentage: b.used_percentage,
           resets_at: (b.resets_at | if type=="string" then toepoch(.) else . end) }
    end;
  .rate_limits as $rl
  | if ($rl|not) or ($rl == {}) then empty
    else { captured_at: $now,
           five_hour: norm($rl.five_hour),
           seven_day: norm($rl.seven_day) }
         + (if $rl.seven_day_sonnet then {seven_day_sonnet: norm($rl.seven_day_sonnet)} else {} end)
    end
' > "$tmp" 2>/dev/null

if [ -s "$tmp" ] && jq -e . "$tmp" >/dev/null 2>&1; then
  mv -f "$tmp" "$cache"
else
  rm -f "$tmp"
fi

if [ "$#" -gt 0 ]; then
  printf '%s' "$input" | "$@"
fi
