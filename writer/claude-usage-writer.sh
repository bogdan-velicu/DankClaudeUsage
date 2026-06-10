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
    # Best-effort ISO-8601 -> epoch. Claude Code currently emits integer epochs;
    # this branch only runs for the ISO-string fallback. Strip any timezone
    # designator (Z or +/-HH:MM / +/-HHMM) and interpret the time as UTC, so a
    # valid ISO timestamp never silently parses to null.
    s | sub("(Z|[+-][0-9]{2}:?[0-9]{2})$"; "") | strptime("%Y-%m-%dT%H:%M:%S") | mktime;
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
