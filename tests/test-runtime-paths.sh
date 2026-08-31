#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
OLD_RUNTIME_NAME='Kindle''Dash'
LEGACY_PROJECT_NAME='Paper''Cast'
NEW_NAME='ForecastInk'
NEW_BASE="/mnt/us/extensions/$NEW_NAME"
INTERMEDIATE_BASE="/mnt/us/extensions/$LEGACY_PROJECT_NAME"

fail(){ echo "FAIL: $*" >&2; exit 1; }

assert_contains(){
  FILE="$1"
  TEXT="$2"
  grep -F "$TEXT" "$FILE" >/dev/null || fail "$FILE does not contain: $TEXT"
}

assert_not_contains(){
  FILE="$1"
  TEXT="$2"
  if grep -F "$TEXT" "$FILE" >/dev/null; then
    fail "$FILE contains an obsolete current-project reference: $TEXT"
  fi
}

RUN="$PROJECT_ROOT/bin/run.sh"
RECOVERY="$PROJECT_ROOT/bin/restore-kindle-ui.sh"
MANIFEST="$PROJECT_ROOT/config.xml"
MENU="$PROJECT_ROOT/menu.json"
README="$PROJECT_ROOT/README.md"
SOURCE_OFFER="$PROJECT_ROOT/SOURCE_OFFER.md"

assert_contains "$RUN" "BASE=\"$NEW_BASE\""
assert_contains "$RECOVERY" "BASE=\"$NEW_BASE\""
assert_contains "$RUN" 'LOG="$BASE/cache/forecastink.log"'
assert_contains "$RECOVERY" 'RECOVERY_LOG="$BASE/cache/forecastink.log"'
assert_contains "$MANIFEST" "<name>$NEW_NAME</name>"
assert_contains "$MANIFEST" "<author>$NEW_NAME</author>"
assert_contains "$MANIFEST" "<id>$NEW_NAME</id>"
assert_contains "$MENU" "\"name\": \"$NEW_NAME\""
assert_contains "$MENU" "Start $NEW_NAME — Hourly only"
assert_contains "$MENU" "Start $NEW_NAME — Cycle all 3 views"
assert_contains "$MENU" '"action": "./bin/run.sh live-hourly"'
assert_contains "$MENU" '"action": "./bin/run.sh live"'
assert_contains "$MENU" '"action": "/bin/sh ./bin/restore-kindle-ui.sh"'
assert_contains "$README" "# $NEW_NAME"
assert_contains "$README" 'A low-power e-ink weather dashboard for jailbroken Kindles.'
assert_contains "$README" 'assets/forecastink-hero.png'
assert_contains "$README" 'assets/forecastink-hourly.jpg'
assert_contains "$README" 'assets/forecastink-dayparts.jpg'
assert_contains "$README" 'assets/forecastink-daily.jpg'
assert_contains "$README" "\`$NEW_NAME/\`"
assert_contains "$README" "$NEW_BASE/config.conf"
assert_contains "$README" "/mnt/us/extensions/$OLD_RUNTIME_NAME/"
assert_contains "$README" "previously released as $LEGACY_PROJECT_NAME"
assert_contains "$SOURCE_OFFER" "https://github.com/inVinnieVeritas/$LEGACY_PROJECT_NAME"

assert_not_contains "$RUN" "$OLD_RUNTIME_NAME"
assert_not_contains "$RUN" "$INTERMEDIATE_BASE"
assert_not_contains "$RECOVERY" "$OLD_RUNTIME_NAME"
assert_not_contains "$RECOVERY" "$INTERMEDIATE_BASE"
assert_not_contains "$MANIFEST" "$OLD_RUNTIME_NAME"
assert_not_contains "$MANIFEST" "$LEGACY_PROJECT_NAME"
assert_not_contains "$MENU" "$LEGACY_PROJECT_NAME"
assert_not_contains "$README" "$INTERMEDIATE_BASE/"

if command -v git >/dev/null 2>&1; then
  OLD_RUNTIME_REFS="$(git -c safe.directory="$PROJECT_ROOT" -C "$PROJECT_ROOT" grep -l "$OLD_RUNTIME_NAME" -- ':!README.md' || true)"
  [ -z "$OLD_RUNTIME_REFS" ] || fail "old runtime name remains outside README.md: $OLD_RUNTIME_REFS"
  LEGACY_PROJECT_REFS="$(git -c safe.directory="$PROJECT_ROOT" -C "$PROJECT_ROOT" grep -l "$LEGACY_PROJECT_NAME" -- ':!README.md' ':!SOURCE_OFFER.md' || true)"
  [ -z "$LEGACY_PROJECT_REFS" ] || fail "legacy project name remains outside historical documentation: $LEGACY_PROJECT_REFS"
fi

echo "All runtime-path tests passed."