#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM
sed -n '/^log_fetch_error()/,/^weather_footer()/p' "$PROJECT_ROOT/bin/run.sh" |
  sed '$d' >"$TEST_ROOT/functions.sh"
. "$TEST_ROOT/functions.sh"

LOG="$TEST_ROOT/log"
FETCH_DETAILS="$TEST_ROOT/capture"
log(){ printf '%s\n' "$*" >>"$LOG"; }
fail(){ printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_contains(){ grep -F "$1" "$LOG" >/dev/null || fail "$2"; }
assert_cleaned(){
  [ ! -e "${FETCH_DETAILS}.limited" ] && [ ! -e "${FETCH_DETAILS}.lines" ] || fail 'scratch files remain'
}

# A BusyBox build may provide head -n but omit optional head -c. Reproduce
# how the old pipeline then returns success while dropping all diagnostics.
head(){
  case "${1:-}" in
    -c) printf 'head: invalid option -- c\n' >&2; return 2 ;;
    *) command head "$@" ;;
  esac
}
printf 'HTTP/1.1 503 Service Unavailable\r\nretry-after: 60\r\n' >"$FETCH_DETAILS"
head -c 2048 "$FETCH_DETAILS" 2>"$TEST_ROOT/legacy-error" |
  tr -d '\r' | head -n 8 >"$TEST_ROOT/legacy-result"
[ ! -s "$TEST_ROOT/legacy-result" ] || fail 'legacy pipeline should discard output when head -c is unsupported'
grep -F 'invalid option' "$TEST_ROOT/legacy-error" >/dev/null || fail 'legacy utility error missing'

# The replacement must work even when every head invocation would fail.
head(){ printf 'unsupported head option\n' >&2; return 2; }
: >"$LOG"
RC=5
WEATHER_LAST_SUCCESS='2026-10-14 07:00'
log_fetch_error
assert_contains 'HTTP/1.1 503 Service Unavailable' 'HTTP status lost with unsupported head'
assert_contains 'retry-after: 60' 'HTTP header lost'
[ "$RC" -eq 5 ] || fail 'logger changed fetch exit status'
[ "$WEATHER_LAST_SUCCESS" = '2026-10-14 07:00' ] || fail 'logger changed saved update time'
assert_cleaned

# Enforce both bounds, remove CR and handle a final fragment without LF.
awk 'BEGIN { for(i=1;i<=20;i++) printf "line-%d\r\n",i }' >"$FETCH_DETAILS"
: >"$LOG"
log_fetch_error
[ "$(wc -l <"$LOG")" -eq 8 ] || fail 'line bound exceeded'
if grep -F 'line-9' "$LOG" >/dev/null; then fail 'ninth line leaked'; fi
CR="$(printf '\r')"
if grep "$CR" "$LOG" >/dev/null; then fail 'CR byte leaked'; fi
awk 'BEGIN { for(i=0;i<4000;i++) printf "x" }' >"$FETCH_DETAILS"
: >"$LOG"
log_fetch_error
[ "$(wc -l <"$LOG")" -eq 1 ] || fail 'truncated fragment lost'
[ "$(wc -c <"$LOG")" -eq 2063 ] || fail '2048-byte bound changed'
assert_cleaned

# Empty, missing and broken diagnostic stages must produce explicit markers
# and return success to the weather caller, never silently swallow evidence.
: >"$FETCH_DETAILS"
: >"$LOG"
log_fetch_error
assert_contains 'xh capture empty' 'empty capture silently ignored'
rm "$FETCH_DETAILS"
: >"$LOG"
log_fetch_error
assert_contains 'byte limiter rc=' 'missing capture silently ignored'
printf 'diagnostic\n' >"$FETCH_DETAILS"
dd(){ printf 'unsupported utility option\n' >&2; return 64; }
: >"$LOG"
log_fetch_error
assert_contains 'byte limiter rc=64' 'limiter failure silently ignored'
unset -f dd
awk(){ printf 'unsupported utility option\n' >&2; return 65; }
: >"$LOG"
log_fetch_error
assert_contains 'line filter rc=65' 'filter failure silently ignored'
unset -f awk
assert_cleaned

# Exercise stderr captured from actual xh 0.16.1, supplied by the Python
# integration test. These are actual HTTP/transport results, not mock output.
if [ -n "${XH_REAL_CAPTURE_DIR:-}" ]; then
  for CASE in 200 503 429 refused; do
    cp "$XH_REAL_CAPTURE_DIR/real-xh-${CASE}.capture" "$FETCH_DETAILS"
    : >"$LOG"
    log_fetch_error
    case "$CASE" in
      refused) assert_contains 'xh: error:' 'real xh transport error lost' ;;
      *) assert_contains " $CASE " 'real xh status lost' ;;
    esac
    if grep -F 'body must not enter diagnostics' "$LOG" >/dev/null; then fail 'response body leaked'; fi
    [ "$(wc -l <"$LOG")" -le 8 ] || fail 'real-output line bound exceeded'
    assert_cleaned
  done
  printf 'PASS: real xh 0.16.1 HTTP/transport captures survive unsupported head\n'
fi
printf 'PASS: logging bounds, CR removal, unsupported options, explicit failures and state preservation\n'
