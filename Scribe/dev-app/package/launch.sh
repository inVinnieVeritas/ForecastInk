#!/bin/sh

BASE="/mnt/us/ForecastInk"
CONFIG_FILE="$BASE/config.conf"
LOG_FILE="$BASE/logs/scribe-dev.log"
XH="./bin/xh"
PLATFORM_MODULE="./lib/scribe-platform.sh"
LOCATION_MODULE="./lib/scribe-location.sh"
WEATHER_MODULE="./lib/scribe-weather.sh"
UI_MODULE="./lib/scribe-ui.sh"

for required_module in "$PLATFORM_MODULE" "$LOCATION_MODULE" "$WEATHER_MODULE" "$UI_MODULE"; do
    if [ ! -r "$required_module" ]; then
        echo "ForecastInk Scribe Dev: required module unavailable: $required_module" >&2
        exit 1
    fi
done

. "$PLATFORM_MODULE"

if ! scribe_log_init "$LOG_FILE"; then
    echo "ForecastInk Scribe Dev: could not initialize $LOG_FILE" >&2
    exit 1
fi

scribe_log "launch_pid=$$"
trap 'launch_exit_code=$?; scribe_log "launch_exit_code=$launch_exit_code"' 0
scribe_log "date_time=$(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null)"

if ! scribe_detect_device; then
    scribe_log "detected_device=${SCRIBE_DEVICE_MODEL:-unavailable}"
    scribe_log "final_status=failure reason=device_detection"
    exit 1
fi
scribe_log "detected_device=$SCRIBE_DEVICE_MODEL"

if ! scribe_detect_architecture; then
    scribe_log "uname_architecture=${SCRIBE_ARCHITECTURE:-unavailable}"
    scribe_log "final_status=failure reason=architecture"
    exit 1
fi
scribe_log "uname_architecture=$SCRIBE_ARCHITECTURE"
scribe_log "logical_screen=${SCRIBE_SCREEN_WIDTH}x${SCRIBE_SCREEN_HEIGHT}"
scribe_log_framebuffer_info

if [ ! -r "$CONFIG_FILE" ]; then
    scribe_log "config_file=$CONFIG_FILE unavailable"
    scribe_log "final_status=failure reason=config"
    exit 1
fi

# The ForecastInk config is intentionally a POSIX shell configuration file.
. "$CONFIG_FILE"
LOCATION="${LOCATION:-Brussels}"
LATITUDE="${LATITUDE:-}"
LONGITUDE="${LONGITUDE:-}"
TIMEZONE="${TIMEZONE:-}"
scribe_log "config_file=$CONFIG_FILE"
scribe_log "configured_LOCATION=$LOCATION"

if [ ! -x "$XH" ]; then
    scribe_log "selected_http_client=$XH unavailable"
    scribe_log "final_status=failure reason=http_client"
    exit 1
fi
scribe_log "selected_http_client=$XH"

if ! scribe_discover_fbink; then
    scribe_log "fbink_path=unavailable"
    scribe_log "final_status=failure reason=fbink"
    exit 1
fi
scribe_log "fbink_path=$SCRIBE_FBINK"

. "$LOCATION_MODULE"
. "$WEATHER_MODULE"
. "$UI_MODULE"

fetch_weather
FETCH_RETURN_CODE=$?
scribe_log "weather_fetch_return_code=$FETCH_RETURN_CODE"

DISPLAY_LOCATION="$LOCATION"
[ -n "$RESOLVED_NAME" ] && DISPLAY_LOCATION="$RESOLVED_NAME"

scribe_log "location_source=${LOCATION_SOURCE:-unavailable}"
scribe_log "resolved_city=${RESOLVED_NAME:-unavailable}"
scribe_log "resolved_region=${RESOLVED_REGION:-unavailable}"
scribe_log "resolved_country=${RESOLVED_COUNTRY:-unavailable}"
scribe_log "latitude=${LATITUDE:-unavailable}"
scribe_log "longitude=${LONGITUDE:-unavailable}"
scribe_log "timezone=${TIMEZONE:-unavailable}"
scribe_log "fetch_state=$FETCH_STATE"
scribe_log "parsed_current_temp=$TEMP"
scribe_log "parsed_feels_like=$FEELS"
scribe_log "parsed_high=$HIGH"
scribe_log "parsed_low=$LOW"
scribe_log "parsed_weather_code=$CODE"
scribe_log "parsed_condition=$CONDITION"
scribe_log "parsed_current_rain_probability=$CURRENT_RAIN"
scribe_log "parsed_current_precipitation=$CURRENT_PRECIP"
scribe_log "parsed_sunrise=$SUNRISE"
scribe_log "parsed_sunset=$SUNSET"
scribe_log "parsed_next_four_hours=$H1_LABEL:$H1_TEMP,$H2_LABEL:$H2_TEMP,$H3_LABEL:$H3_TEMP,$H4_LABEL:$H4_TEMP"
scribe_log "parsed_dayparts=$P1_LABEL:$P1_TEMP,$P2_LABEL:$P2_TEMP,$P3_LABEL:$P3_TEMP,$P4_LABEL:$P4_TEMP"
scribe_log "daily_array_lengths=dates:$DAILY_DATE_COUNT,max:$DAILY_MAX_COUNT,min:$DAILY_MIN_COUNT"
scribe_log "daily_future_complete=$DAILY_COMPLETE_FUTURE_COUNT/7"
scribe_log "parsed_daily=$D1_LABEL:$D1_HIGH/$D1_LOW,$D2_LABEL:$D2_HIGH/$D2_LOW,$D3_LABEL:$D3_HIGH/$D3_LOW,$D4_LABEL:$D4_HIGH/$D4_LOW,$D5_LABEL:$D5_HIGH/$D5_LOW,$D6_LABEL:$D6_HIGH/$D6_LOW,$D7_LABEL:$D7_HIGH/$D7_LOW"

FULL_DATE="$(date '+%A, %B %d, %Y' 2>/dev/null)"
[ -n "$FULL_DATE" ] || FULL_DATE="Date unavailable"

if ! scribe_ui_prepare; then
    scribe_log "main_render_result=capability_failure"
    scribe_ui_render_capability_failure "$SCRIBE_UI_CAPABILITY_ERROR"
    CAPABILITY_RENDER_RETURN_CODE=$?
    scribe_log "capability_screen_return_code=$CAPABILITY_RENDER_RETURN_CODE"
    scribe_log "display_hold_seconds=30"
    sleep 30
    scribe_log "final_status=failure reason=render_capability"
    exit 1
fi

scribe_log "render_start=true"
scribe_ui_render_dashboard "$DISPLAY_LOCATION" "$FULL_DATE"
MAIN_RENDER_RETURN_CODE=$?
scribe_log "main_render_return_code=$MAIN_RENDER_RETURN_CODE"

if [ "$MAIN_RENDER_RETURN_CODE" -ne 0 ]; then
    scribe_log "main_render_result=failure"
    scribe_ui_render_capability_failure "Dashboard render failed"
    sleep 30
    scribe_log "final_status=failure reason=render"
    exit "$MAIN_RENDER_RETURN_CODE"
fi

scribe_log "main_render_result=success"
scribe_log "display_hold_seconds=30"
sleep 30
SLEEP_RETURN_CODE=$?
scribe_log "sleep_return_code=$SLEEP_RETURN_CODE"

if [ "$SLEEP_RETURN_CODE" -ne 0 ]; then
    scribe_log "final_status=failure reason=display_hold"
    exit "$SLEEP_RETURN_CODE"
fi

scribe_log "final_status=success fetch_state=$FETCH_STATE"
exit 0
