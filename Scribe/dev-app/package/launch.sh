#!/bin/sh

BASE="/mnt/us/ForecastInk"
CONFIG_FILE="$BASE/config.conf"
LOG_FILE="$BASE/logs/scribe-dev.log"
XH="./bin/xh"
PLATFORM_MODULE="./lib/scribe-platform.sh"
LOCATION_MODULE="./lib/scribe-location.sh"
WEATHER_MODULE="./lib/scribe-weather.sh"

for required_module in "$PLATFORM_MODULE" "$LOCATION_MODULE" "$WEATHER_MODULE"; do
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
scribe_log "parsed_daily=$D1_LABEL:$D1_HIGH/$D1_LOW,$D2_LABEL:$D2_HIGH/$D2_LOW,$D3_LABEL:$D3_HIGH/$D3_LOW,$D4_LABEL:$D4_HIGH/$D4_LOW"

MESSAGE="$(printf 'ForecastInk\n\n%s\n\n%s°C\nFeels %s°C\n\nHigh %s°   Low %s°\nRain %s%% / %s mm\n\nSunrise %s\nSunset %s\n\n%s\nUpdated %s' \
    "$DISPLAY_LOCATION" "$TEMP" "$FEELS" "$HIGH" "$LOW" \
    "$CURRENT_RAIN" "$CURRENT_PRECIP" "$SUNRISE" "$SUNSET" \
    "$FETCH_STATE" "$WEATHER_UPDATED")"

scribe_log "render_start=true"
scribe_log "fbink_command=$SCRIBE_FBINK -q -c -m -M -w -S 6 -C BLACK -B WHITE -- <weather diagnostic>"
"$SCRIBE_FBINK" -q -c -m -M -w -S 6 -C BLACK -B WHITE -- "$MESSAGE" >>"$SCRIBE_LOG_FILE" 2>&1
FBINK_RETURN_CODE=$?
scribe_log "fbink_return_code=$FBINK_RETURN_CODE"

if [ "$FBINK_RETURN_CODE" -ne 0 ]; then
    scribe_log "final_status=failure reason=render"
    exit "$FBINK_RETURN_CODE"
fi

scribe_log "display_hold_seconds=15"
sleep 15
SLEEP_RETURN_CODE=$?
scribe_log "sleep_return_code=$SLEEP_RETURN_CODE"

if [ "$SLEEP_RETURN_CODE" -ne 0 ]; then
    scribe_log "final_status=failure reason=display_hold"
    exit "$SLEEP_RETURN_CODE"
fi

scribe_log "final_status=success fetch_state=$FETCH_STATE"
exit 0
