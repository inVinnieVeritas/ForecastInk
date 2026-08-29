#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
TEST_ROOT="${TMPDIR:-/tmp}/papercast-location-test.$$"

case "$TEST_ROOT" in
  "${TMPDIR:-/tmp}"/papercast-location-test.*) ;;
  *) echo "unsafe test directory: $TEST_ROOT" >&2; exit 1 ;;
esac

cleanup(){ rm -rf "$TEST_ROOT"; }
trap cleanup EXIT HUP INT TERM

mkdir -p "$TEST_ROOT/base/cache"
BASE="$TEST_ROOT/base"
LOG="$BASE/cache/test.log"
TEST_REQUESTS="$TEST_ROOT/requests"
TEST_LAST_QUERY="$TEST_ROOT/last-query"
TEST_FIXTURE="$TEST_ROOT/geocode.json"
XH="$TEST_ROOT/mock-xh"
export TEST_REQUESTS TEST_LAST_QUERY TEST_FIXTURE MOCK_GEOCODE_MODE

cat >"$XH" <<'MOCK'
#!/bin/sh
OUT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) OUT="$2"; shift 2 ;;
    name==*) printf '%s\n' "${1#name==}" >"$TEST_LAST_QUERY"; shift ;;
    *) shift ;;
  esac
done
printf 'request\n' >>"$TEST_REQUESTS"
case "${MOCK_GEOCODE_MODE:-failure}" in
  success) cp "$TEST_FIXTURE" "$OUT"; exit 0 ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "$XH"

log(){ printf '%s\n' "$*" >>"$LOG"; }
. "$PROJECT_ROOT/bin/location.sh"

fail(){ echo "FAIL: $*" >&2; exit 1; }
assert_eq(){
  [ "$1" = "$2" ] || fail "$3 (expected '$2', got '$1')"
}
assert_file(){ [ -f "$1" ] || fail "missing file: $1"; }
request_count(){
  if [ -f "$TEST_REQUESTS" ]; then wc -l <"$TEST_REQUESTS" | tr -d ' '; else echo 0; fi
}
reset_runtime(){
  LOCATION_READY=0
  LOCATION_SOURCE=""
  RESOLVED_NAME=""
  RESOLVED_COUNTRY=""
  RESOLVED_REGION=""
  LATITUDE=""
  LONGITUDE=""
  TIMEZONE=""
  rm -f "$TEST_LAST_QUERY"
  : >"$TEST_REQUESTS"
  : >"$LOG"
}
clear_cache(){
  rm -f "$GEOCODE_CACHE" "$GEOCODE_CACHE_QUERY" "$GEOCODE_TMP" \
    "${GEOCODE_CACHE}.new" "${GEOCODE_CACHE_QUERY}.new"
}
write_fixture(){
  NAME="$1"; LAT="$2"; LON="$3"; ZONE="$4"; COUNTRY="$5"; REGION="$6"
  printf '{"results":[{"name":"%s","latitude":%s,"longitude":%s,"timezone":"%s","country":"%s","admin1":"%s"}]}' \
    "$NAME" "$LAT" "$LON" "$ZONE" "$COUNTRY" "$REGION" >"$TEST_FIXTURE"
}
prime_cache(){
  QUERY="$1"
  cp "$TEST_FIXTURE" "$GEOCODE_CACHE"
  printf '%s\n' "$QUERY" >"$GEOCODE_CACHE_QUERY"
}

assert_lookup_query(){
  INPUT_QUERY="$1"
  EXPECTED_QUERY="$2"
  clear_cache; reset_runtime
  LOCATION="$INPUT_QUERY"
  write_fixture "Resolved" "1.0" "2.0" "UTC" "Test Country" "Test Region"
  MOCK_GEOCODE_MODE=success; export MOCK_GEOCODE_MODE
  resolve_location || fail "query lookup failed for $INPUT_QUERY"
  assert_eq "$(sed -n '1p' "$TEST_LAST_QUERY")" "$EXPECTED_QUERY" "request query for $INPUT_QUERY"
  assert_eq "$(sed -n '1p' "$GEOCODE_CACHE_QUERY")" "$INPUT_QUERY" "cache key for $INPUT_QUERY"
  assert_eq "$LOCATION" "$INPUT_QUERY" "display label for $INPUT_QUERY"
  assert_eq "$(request_count)" "1" "request count for $INPUT_QUERY"
}

echo "1. city-only configuration"
clear_cache; reset_runtime
LOCATION="Bangkok"
write_fixture "Bangkok" "13.7525" "100.4942" "Asia/Bangkok" "Thailand" "Bangkok"
MOCK_GEOCODE_MODE=success; export MOCK_GEOCODE_MODE
resolve_location || fail "city-only lookup failed"
assert_eq "$LATITUDE" "13.7525" "city-only latitude"
assert_eq "$LONGITUDE" "100.4942" "city-only longitude"
assert_eq "$TIMEZONE" "Asia/Bangkok" "city-only timezone"
assert_eq "$LOCATION_SOURCE" "geocoding" "city-only source"
assert_eq "$(request_count)" "1" "city-only request count"
assert_file "$GEOCODE_CACHE"
assert_file "$GEOCODE_CACHE_QUERY"

echo "2. explicit coordinate override"
clear_cache; reset_runtime
LOCATION="London"
LATITUDE="51.5074"; LONGITUDE="-0.1278"; TIMEZONE="Europe/London"
MOCK_GEOCODE_MODE=failure; export MOCK_GEOCODE_MODE
resolve_location || fail "explicit override failed"
assert_eq "$LOCATION_SOURCE" "explicit" "explicit source"
assert_eq "$(request_count)" "0" "explicit request count"

echo "3. cached result reuse while offline"
clear_cache; reset_runtime
LOCATION="Bangkok"
write_fixture "Bangkok" "13.7525" "100.4942" "Asia/Bangkok" "Thailand" "Bangkok"
prime_cache "$LOCATION"
MOCK_GEOCODE_MODE=failure; export MOCK_GEOCODE_MODE
resolve_location || fail "valid cache was not reused"
assert_eq "$LOCATION_SOURCE" "cache" "cache source"
assert_eq "$TIMEZONE" "Asia/Bangkok" "cached timezone"
assert_eq "$(request_count)" "0" "cache should avoid network"

echo "4. failed geocoding without cache"
clear_cache; reset_runtime
LOCATION="Nowhere"
MOCK_GEOCODE_MODE=failure; export MOCK_GEOCODE_MODE
if resolve_location; then fail "failed geocoding unexpectedly succeeded"; fi
assert_eq "$LOCATION_READY" "0" "failed lookup readiness"
assert_eq "$(request_count)" "1" "failed lookup request count"
[ ! -f "$GEOCODE_CACHE" ] || fail "failed lookup created a cache"

echo "5. location change invalidates previous cache"
clear_cache; reset_runtime
write_fixture "Bangkok" "13.7525" "100.4942" "Asia/Bangkok" "Thailand" "Bangkok"
prime_cache "Bangkok"
LOCATION="London"
write_fixture "London" "51.5085" "-0.1257" "Europe/London" "United Kingdom" "England"
MOCK_GEOCODE_MODE=success; export MOCK_GEOCODE_MODE
resolve_location || fail "changed location lookup failed"
assert_eq "$LOCATION_SOURCE" "geocoding" "changed location source"
assert_eq "$LATITUDE" "51.5085" "changed location latitude"
assert_eq "$(request_count)" "1" "changed location request count"
assert_eq "$(sed -n '1p' "$GEOCODE_CACHE_QUERY")" "London" "changed cache key"

echo "6. invalid matching cache is refreshed"
clear_cache; reset_runtime
LOCATION="Montréal"
printf '%s\n' '{"results":[]}' >"$GEOCODE_CACHE"
printf '%s\n' "$LOCATION" >"$GEOCODE_CACHE_QUERY"
write_fixture "Montreal" "45.5088" "-73.5878" "America/Toronto" "Canada" "Quebec"
MOCK_GEOCODE_MODE=success; export MOCK_GEOCODE_MODE
resolve_location || fail "invalid cache refresh failed"
assert_eq "$LATITUDE" "45.5088" "refreshed cache latitude"
assert_eq "$TIMEZONE" "America/Toronto" "refreshed cache timezone"
assert_eq "$(request_count)" "1" "invalid cache refresh request count"


echo "7. simple, ambiguous, UK-alias, and non-ASCII queries"
assert_lookup_query "London" "London"
assert_lookup_query "London, Ontario" "London, Ontario"
assert_lookup_query "Paris" "Paris"
assert_lookup_query "Paris, Texas" "Paris, Texas"
assert_lookup_query "Cambridge, UK" "Cambridge, United Kingdom"
assert_lookup_query "Montréal" "Montréal"
echo "All automatic-location tests passed."
