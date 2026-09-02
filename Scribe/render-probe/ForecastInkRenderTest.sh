#!/bin/sh

LOG_DIRECTORY="/mnt/us/ForecastInk/logs"
LOG_FILE="$LOG_DIRECTORY/render-probe.log"

if ! mkdir -p "$LOG_DIRECTORY"; then
    exit 1
fi

if ! : >"$LOG_FILE"; then
    exit 1
fi

exec >>"$LOG_FILE" 2>&1

log_value() {
    label="$1"
    path="$2"

    if [ -r "$path" ]; then
        value="$(cat "$path" 2>/dev/null)"
        printf '%s=%s\n' "$label" "${value:-unavailable}"
    else
        printf '%s=unavailable\n' "$label"
    fi
}

RENDER_TIME="$(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null)"
if [ -z "$RENDER_TIME" ]; then
    RENDER_TIME="unavailable"
fi

printf 'date_time=%s\n' "$RENDER_TIME"

FBINK=""
if [ -x "/var/local/kmc/bin/fbink" ]; then
    FBINK="/var/local/kmc/bin/fbink"
elif [ -x "/mnt/us/libkh/bin/fbink" ]; then
    FBINK="/mnt/us/libkh/bin/fbink"
fi

if [ -z "$FBINK" ]; then
    echo "fbink_path=unavailable"
    echo "error=No executable FBInk binary found at the supported paths."
    echo "final_status=failure"
    exit 1
fi

printf 'fbink_path=%s\n' "$FBINK"
log_value "fb0_name" "/sys/class/graphics/fb0/name"
log_value "fb0_virtual_size" "/sys/class/graphics/fb0/virtual_size"
log_value "fb0_bits_per_pixel" "/sys/class/graphics/fb0/bits_per_pixel"
log_value "fb0_stride" "/sys/class/graphics/fb0/stride"
log_value "fb0_rotate" "/sys/class/graphics/fb0/rotate"

MESSAGE="$(printf 'ForecastInk\n\nKindle Scribe detected\n\n1860 x 2480\n\n%s' "$RENDER_TIME")"

echo "render_start=true"
echo "fbink_command=$FBINK -q -c -m -M -w -S 6 -C BLACK -B WHITE -- <multiline message>"
"$FBINK" -q -c -m -M -w -S 6 -C BLACK -B WHITE -- "$MESSAGE"
FBINK_RETURN_CODE=$?
printf 'fbink_return_code=%s\n' "$FBINK_RETURN_CODE"

if [ "$FBINK_RETURN_CODE" -ne 0 ]; then
    echo "final_status=failure"
    exit "$FBINK_RETURN_CODE"
fi

echo "render_complete=true"
echo "display_hold_seconds=10"
sleep 10
SLEEP_RETURN_CODE=$?
printf 'sleep_return_code=%s\n' "$SLEEP_RETURN_CODE"

if [ "$SLEEP_RETURN_CODE" -ne 0 ]; then
    echo "final_status=failure"
    exit "$SLEEP_RETURN_CODE"
fi

echo "final_status=success"
exit 0

