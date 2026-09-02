#!/bin/sh

PLATFORM_MODULE="./lib/scribe-platform.sh"
LOG_FILE="/mnt/us/ForecastInk/logs/scribe-dev.log"

if [ ! -r "$PLATFORM_MODULE" ]; then
    echo "ForecastInk Scribe Dev: platform module is unavailable." >&2
    exit 1
fi

. "$PLATFORM_MODULE"

if ! scribe_log_init "$LOG_FILE"; then
    echo "ForecastInk Scribe Dev: could not initialize $LOG_FILE" >&2
    exit 1
fi

RENDER_TIME="$(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null)"
if [ -z "$RENDER_TIME" ]; then
    RENDER_TIME="unavailable"
fi

scribe_log "date_time=$RENDER_TIME"

if ! scribe_detect_device; then
    scribe_log "detected_device=${SCRIBE_DEVICE_MODEL:-unavailable}"
    scribe_log "error=Kindle Scribe was not detected."
    scribe_log "final_status=failure"
    exit 1
fi
scribe_log "detected_device=$SCRIBE_DEVICE_MODEL"

if ! scribe_detect_architecture; then
    scribe_log "uname_architecture=${SCRIBE_ARCHITECTURE:-unavailable}"
    scribe_log "error=Expected armv7l architecture."
    scribe_log "final_status=failure"
    exit 1
fi
scribe_log "uname_architecture=$SCRIBE_ARCHITECTURE"

scribe_log "logical_screen_width=$SCRIBE_SCREEN_WIDTH"
scribe_log "logical_screen_height=$SCRIBE_SCREEN_HEIGHT"
scribe_log_framebuffer_info

if ! scribe_discover_fbink; then
    scribe_log "fbink_path=unavailable"
    scribe_log "error=No executable FBInk binary found at the supported paths."
    scribe_log "final_status=failure"
    exit 1
fi
scribe_log "fbink_path=$SCRIBE_FBINK"

MESSAGE="$(printf 'ForecastInk\n\nKindle Scribe detected\n\n%s x %s\n\n%s' "$SCRIBE_SCREEN_WIDTH" "$SCRIBE_SCREEN_HEIGHT" "$RENDER_TIME")"

scribe_log "render_start=true"
scribe_log "fbink_command=$SCRIBE_FBINK -q -c -m -M -w -S 6 -C BLACK -B WHITE -- <multiline message>"
"$SCRIBE_FBINK" -q -c -m -M -w -S 6 -C BLACK -B WHITE -- "$MESSAGE" >>"$SCRIBE_LOG_FILE" 2>&1
FBINK_RETURN_CODE=$?
scribe_log "fbink_return_code=$FBINK_RETURN_CODE"

if [ "$FBINK_RETURN_CODE" -ne 0 ]; then
    scribe_log "final_status=failure"
    exit "$FBINK_RETURN_CODE"
fi

scribe_log "display_hold_seconds=10"
sleep 10
SLEEP_RETURN_CODE=$?
scribe_log "sleep_return_code=$SLEEP_RETURN_CODE"

if [ "$SLEEP_RETURN_CODE" -ne 0 ]; then
    scribe_log "final_status=failure"
    exit "$SLEEP_RETURN_CODE"
fi

scribe_log "final_status=success"
exit 0

