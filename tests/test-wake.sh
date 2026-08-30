#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
. "$PROJECT_ROOT/bin/wake.sh"

fail(){ echo "FAIL: $*" >&2; exit 1; }

assert_reason(){
  LABEL="$1"
  EXPECTED_REASON="$2"
  EXPECTED_EPOCH="$3"
  ACTUAL_EPOCH="$4"
  TOLERANCE="$5"
  ACTUAL_REASON="$(classify_resume "$EXPECTED_EPOCH" "$ACTUAL_EPOCH" "$TOLERANCE")"
  [ "$ACTUAL_REASON" = "$EXPECTED_REASON" ] || \
    fail "$LABEL (expected '$EXPECTED_REASON', got '$ACTUAL_REASON')"
}

TARGET=2000000000

assert_reason "three seconds after target" rtc "$TARGET" $((TARGET + 3)) 90
assert_reason "twenty seconds before target" rtc "$TARGET" $((TARGET - 20)) 90
assert_reason "exactly at target" rtc "$TARGET" "$TARGET" 90
assert_reason "exactly ninety seconds early" rtc "$TARGET" $((TARGET - 90)) 90
assert_reason "ninety-one seconds early" external-early "$TARGET" $((TARGET - 91)) 90
assert_reason "fifteen minutes early" external-early "$TARGET" $((TARGET - 900)) 90
assert_reason "thirty-nine minutes thirty seconds early" external-early "$TARGET" $((TARGET - 2370)) 90
assert_reason "late resume remains RTC" rtc "$TARGET" $((TARGET + 300)) 90

[ "$(resume_delta "$TARGET" $((TARGET - 2370)))" = "-2370" ] || fail "negative delta"
[ "$(resume_delta "$TARGET" $((TARGET + 3)))" = "3" ] || fail "positive delta"

if classify_resume invalid "$TARGET" 90 >/dev/null 2>&1; then
  fail "invalid epoch was accepted"
fi

echo "All wake-classification tests passed."
