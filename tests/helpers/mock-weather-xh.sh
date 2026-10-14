#!/bin/sh
set -eu
OUT=""
HEADERS=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) OUT="$2"; shift ;;
    --print=h) HEADERS=1 ;;
  esac
  shift
done
[ -n "$OUT" ] || exit 99
[ "$HEADERS" -eq 1 ] || { echo 'response-body-secret'; exit 99; }
case "$MOCK_WEATHER_RC" in
  0)
    printf 'HTTP/1.1 200 OK\r\ncontent-type: application/json\r\n\r\n'
    cp "$MOCK_WEATHER_BODY" "$OUT"
    ;;
  5)
    printf 'HTTP/1.1 503 Service Unavailable\r\nretry-after: 60\r\nserver: fixture\r\n'
    I=1
    while [ "$I" -le 10 ]; do printf 'diagnostic-line-%s\r\n' "$I"; I=$((I + 1)); done
    printf 'SHOULD_NOT_BE_LOGGED\r\n'
    ;;
  1) printf 'xh: error: dns error: failed to lookup address information\n' >&2 ;;
esac
exit "$MOCK_WEATHER_RC"
