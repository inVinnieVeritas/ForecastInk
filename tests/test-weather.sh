#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

# Exercise the actual production functions, without running the launcher,
# framebuffer, Wi-Fi, suspend or Kindle services. Redirect only scratch paths.
sed -n '/^condition_text()/,/^battery()/p' "$PROJECT_ROOT/bin/run.sh" |
  sed '$d' | sed "s|/tmp/kd_|$TEST_ROOT/kd_|g; s|/tmp/forecastink-fetch|$TEST_ROOT/forecastink-fetch|g" >"$TEST_ROOT/functions.sh"
. "$TEST_ROOT/functions.sh"

fail(){ printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_equal(){ [ "$1" = "$2" ] || fail "$3: expected '$2', got '$1'"; }
assert_matches(){ weather_cache_matches || fail "$*"; }
assert_rejected(){ if weather_cache_matches; then fail "$*"; fi; }
fetch_fails(){ if fetch_weather; then fail 'failed fetch returned success'; fi; }
resolve_location(){ return 0; }
log(){ printf '%s\n' "$*" >>"$LOG"; }

TEST_DAY=2026-09-18
TEST_HOUR=03
TEST_MINUTE=00
date(){
  case "$1" in
    '+%Y-%m-%d') printf '%s\n' "$TEST_DAY" ;;
    '+%Y-%m-%dT%H:00') printf '%sT%s:00\n' "$TEST_DAY" "$TEST_HOUR" ;;
    '+%H') printf '%s\n' "$TEST_HOUR" ;;
    '+%Y-%m-%d %H:%M') printf '%s %s:%s\n' "$TEST_DAY" "$TEST_HOUR" "$TEST_MINUTE" ;;
    *) command date "$@" ;;
  esac
}

CACHE="$TEST_ROOT/weather.json"
TMP="$TEST_ROOT/weather-latest.json"
WEATHER_CACHE_LOCATION="$TEST_ROOT/weather.location"
LOG="$TEST_ROOT/weather.log"
XH="$TEST_ROOT/xh"
cp "$SCRIPT_DIR/helpers/mock-weather-xh.sh" "$XH"
chmod +x "$XH"
LATITUDE=50.85045
LONGITUDE=4.34878
TIMEZONE=Europe/Brussels
LOCATION=Brussels
LOCATION_SOURCE=explicit
MOCK_WEATHER_BODY="$TEST_ROOT/response.json"
MOCK_WEATHER_RC=0
export MOCK_WEATHER_BODY MOCK_WEATHER_RC

# Compact Open-Meteo-shaped fixture, five days / 120 hours. No network.
awk 'BEGIN {
  printf "{\"current\":{\"temperature_2m\":20,\"apparent_temperature\":19,\"weather_code\":3,\"is_day\":1},\"hourly\":{\"time\":["
  for(i=0;i<120;i++) printf "%s\"2026-09-%02dT%02d:00\"",(i?",":""),18+int(i/24),i%24
  printf "],\"temperature_2m\":["
  for(i=0;i<120;i++) printf "%s%d",(i?",":""),10+int(i/24)
  printf "],\"weather_code\":["
  for(i=0;i<120;i++) printf "%s3",(i?",":"")
  printf "],\"is_day\":["
  for(i=0;i<120;i++) printf "%s1",(i?",":"")
  printf "],\"precipitation_probability\":["
  for(i=0;i<120;i++) printf "%s%s",(i?",":""),(i==5?"null":"0")
  printf "],\"precipitation\":["
  for(i=0;i<120;i++) printf "%s%s",(i?",":""),(i==8?"null":"0")
  printf " ]},\"daily\":{\"time\":["
  for(i=0;i<5;i++) printf "%s\"2026-09-%02d\"",(i?",":""),18+i
  printf "],\"temperature_2m_max\":[25,26,27,28,29],\"temperature_2m_min\":[10,11,12,13,14],\"weather_code\":[3,3,3,3,3],\"precipitation_sum\":[0,null,0,0,0],\"precipitation_probability_max\":[0,null,0,0,0],\"sunrise\":[\"2026-09-18T07:20\"],\"sunset\":[\"2026-09-18T19:50\"]}}\n"
}' | sed 's/ ]/]/g' >"$MOCK_WEATHER_BODY"
cp "$MOCK_WEATHER_BODY" "$TEST_ROOT/good.json"
cp "$MOCK_WEATHER_BODY" "$CACHE"

# Reproduce RC1's exact bug, then accept both newline-less and new keys.
printf '%s' "$(weather_location_key)" >"$WEATHER_CACHE_LOCATION"
if IFS= read -r OLD_KEY <"$WEATHER_CACHE_LOCATION"; then fail 'legacy read should return EOF failure'; fi
assert_equal "$OLD_KEY" "$(weather_location_key)" 'read still populated the matching key'
assert_matches 'RC1 newline-less key must match'
printf '%s\n' "$(weather_location_key)" >"$WEATHER_CACHE_LOCATION"
assert_matches 'newline-terminated key must match'
LONGITUDE=5
assert_rejected 'changed longitude must invalidate'
LONGITUDE=4.34878
LATITUDE=51
assert_rejected 'changed latitude must invalidate'
LATITUDE=50.85045
TIMEZONE=Europe/Paris
assert_rejected 'changed timezone must invalidate even at identical coordinates'
TIMEZONE=Europe/Brussels
rm "$WEATHER_CACHE_LOCATION"
assert_rejected 'unkeyed cache is unsafe even with explicit coordinates'
: >"$WEATHER_CACHE_LOCATION"
assert_rejected 'empty key must not match'

# Legacy fallback, including a time from its last write (not failed fetch).
printf '%s' "$(weather_location_key)" >"$WEATHER_CACHE_LOCATION"
touch -t 202609180300 "$CACHE"
LEGACY_TIME="$(command date -r "$CACHE" '+%Y-%m-%d %H:%M')"
MOCK_WEATHER_RC=5
fetch_fails
assert_equal "$FETCH_STATE" CACHED 'legacy HTTP 503 fallback'
assert_equal "$TEMP" 20 'cached current temperature'
assert_equal "$WEATHER_LAST_SUCCESS" "$LEGACY_TIME" 'legacy mtime retained'
assert_equal "$(weather_footer)" "STALE / OFFLINE  $LEGACY_TIME" 'explicit stale footer'

# Success persists an identity and fetch time; HTTP and DNS failures retain
# the forecast/time, including after a new process has no in-memory time.
MOCK_WEATHER_RC=0
fetch_weather || fail 'first success'
assert_equal "$FETCH_STATE" LIVE 'live result'
assert_equal "$(sed -n '2p' "$WEATHER_CACHE_LOCATION")" '2026-09-18 03:00' 'saved successful time'
assert_equal "$H2_RAIN" -- 'null hourly rain is unknown, not 0%'
assert_equal "$P1_PRECIP" -- 'partly missing daypart total is unknown'
assert_equal "$D1_RAIN" -- 'null daily probability is unknown'
assert_equal "$D1_MM" -- 'null daily precipitation is unknown'
assert_equal "$CURRENT_RAIN" 0 'real zero probability remains zero'
assert_equal "$CURRENT_PRECIP" 0.0 'real zero precipitation remains zero'
KEY_BEFORE="$(cat "$WEATHER_CACHE_LOCATION")"
CACHE_BEFORE="$(cksum <"$CACHE")"
TEST_HOUR=04
WEATHER_LAST_SUCCESS=""
WEATHER_UPDATED=""
MOCK_WEATHER_RC=5
fetch_fails
assert_equal "$FETCH_STATE" CACHED 'HTTP 5xx fallback'
assert_equal "$WEATHER_LAST_SUCCESS" '2026-09-18 03:00' 'HTTP failure cannot advance update time'
MOCK_WEATHER_RC=1
TEST_HOUR=05
fetch_fails
assert_equal "$FETCH_STATE" CACHED 'DNS fallback'
assert_equal "$WEATHER_UPDATED" 03:00 'DNS failure cannot advance update time'
assert_equal "$(cat "$WEATHER_CACHE_LOCATION")" "$KEY_BEFORE" 'failures preserve metadata'
assert_equal "$(cksum <"$CACHE")" "$CACHE_BEFORE" 'failures preserve payload'
grep -F 'HTTP/1.1 503 Service Unavailable' "$LOG" >/dev/null || fail 'HTTP status missing from diagnostics'
grep -F 'dns error: failed to lookup address information' "$LOG" >/dev/null || fail 'DNS cause missing from diagnostics'
if grep -F 'SHOULD_NOT_BE_LOGGED' "$LOG" >/dev/null; then fail 'error logging exceeds line limit'; fi
if grep -F 'response-body-secret' "$LOG" >/dev/null; then fail 'fetch must request headers only'; fi

# Keep cached hourly/daypart/daily forecasts aligned across midnight; after
# the forecast horizon, no old slot or missing precipitation becomes zero.
TEST_DAY=2026-09-19
TEST_HOUR=03
fetch_fails
assert_equal "$HIGH" 26 'cached today uses second day'
assert_equal "$H1_TEMP" 11 'cached next hour uses second day'
assert_equal "$D1_HIGH" 27 'cached tomorrow uses third day'
assert_equal "$P1_TEMP" 11 'cached daypart uses second day'
assert_equal "$WEATHER_LAST_SUCCESS" '2026-09-18 03:00' 'cross-midnight timestamp remains truthful'
TEST_DAY=2026-09-24
fetch_fails
assert_equal "$CURRENT_RAIN" -- 'expired hourly precipitation is unknown'
assert_equal "$H1_TEMP" -- 'expired next-hour temperature is unknown'
assert_equal "$D1_RAIN" -- 'expired daily precipitation is unknown'

# A bad 200 response must not poison the good saved pair.
TEST_DAY=2026-09-18
TEST_HOUR=06
MOCK_WEATHER_RC=0
printf '{"error":true,"reason":"bad response"}\n' >"$MOCK_WEATHER_BODY"
fetch_fails
assert_equal "$FETCH_STATE" CACHED 'unusable HTTP 200 falls back'
assert_equal "$(cksum <"$CACHE")" "$CACHE_BEFORE" 'unusable response cannot replace cache'

# Different configured location/timezone must never reuse the old data.
MOCK_WEATHER_RC=5
LATITUDE=51
fetch_fails
assert_equal "$FETCH_STATE" OFFLINE 'different coordinates rejected'
assert_equal "$TEMP" -- 'different coordinates cannot show old temperature'
assert_equal "$CURRENT_RAIN" -- 'no cache does not claim measured 0%'
LATITUDE=50.85045
TIMEZONE=Europe/Paris
fetch_fails
assert_equal "$FETCH_STATE" OFFLINE 'different timezone rejected'
TIMEZONE=Europe/Brussels

# Recovery replaces the saved forecast/time, clears stale status and keeps
# the original return-value contract (only success advances Cycle).
cp "$TEST_ROOT/good.json" "$MOCK_WEATHER_BODY"
MOCK_WEATHER_RC=0
TEST_HOUR=18
fetch_weather || fail 'recovery success'
assert_equal "$FETCH_STATE" LIVE 'recovery clears stale state'
assert_equal "$WEATHER_UPDATED" 18:00 'recovery refreshes timestamp'
assert_equal "$(sed -n '2p' "$WEATHER_CACHE_LOCATION")" '2026-09-18 18:00' 'recovery saved time'
assert_equal "$(weather_footer)" 'LAST REFRESHED  18:00' 'normal footer restored'

# Staging failure preserves the existing committed cache pair.
cp(){ return 1; }
if save_weather_cache; then fail 'staging failure returned success'; fi
assert_matches 'staging failure preserves cache identity'
assert_equal "$(sed -n '2p' "$WEATHER_CACHE_LOCATION")" '2026-09-18 18:00' 'staging failure preserves time'
unset -f cp

# An interruption after metadata invalidation must not let the new payload
# inherit the old coordinates, even if the final identity rename fails.
mv(){
  if [ "$2" = "$WEATHER_CACHE_LOCATION" ]; then return 1; fi
  command mv "$@"
}
LATITUDE=51
if save_weather_cache; then fail 'interrupted metadata rename returned success'; fi
assert_rejected 'interrupted save leaves no trusted identity'
LATITUDE=50.85045
assert_rejected 'interrupted save cannot bless replacement payload with old identity'
unset -f mv

# Truncated diagnostics still log a bounded final fragment without LF.
FETCH_DETAILS="$TEST_ROOT/long-error"
awk 'BEGIN { for(i=0;i<4000;i++) printf "x" }' >"$FETCH_DETAILS"
LINES_BEFORE="$(wc -l <"$LOG")"
log_fetch_error
LINES_AFTER="$(wc -l <"$LOG")"
assert_equal "$((LINES_AFTER - LINES_BEFORE))" 1 'long diagnostics produce one bounded line'
assert_equal "$(tail -n 1 "$LOG" | wc -c | tr -d ' ')" 2063 'diagnostic payload limited to 2048 bytes plus prefix/newline'

assert_equal "$(format_percent '')" -- 'empty probability'
assert_equal "$(format_percent null)" -- 'null probability'
assert_equal "$(format_percent 101)" -- 'invalid probability'
assert_equal "$(format_precip null)" -- 'null precipitation'
printf 'PASS: weather cache matching, invalidation, fallback, diagnostics, date alignment and recovery\n'
