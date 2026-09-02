#!/bin/sh

# Minimal weather/cache layer adapted from ForecastInk's existing PW1 data logic.
WEATHER_CACHE="$BASE/cache/weather.json"
WEATHER_TMP="$BASE/cache/weather-latest.json"
WEATHER_CACHE_LOCATION="$BASE/cache/weather.location"
WEATHER_CACHE_UPDATED="$BASE/cache/weather.updated"
PARSE_PREFIX="$BASE/cache/scribe-parse.$$"

condition_text() {
    case "$1" in
        0) echo Clear ;;
        1) echo "Mainly clear" ;;
        2) echo "Partly cloudy" ;;
        3) echo Overcast ;;
        45|48) echo Fog ;;
        51|53|55|56|57) echo Drizzle ;;
        61|63|65|66|67) echo Rain ;;
        71|73|75|77) echo Snow ;;
        80|81|82) echo "Rain showers" ;;
        85|86) echo "Snow showers" ;;
        95|96|99) echo Thunderstorm ;;
        *) echo "Weather unavailable" ;;
    esac
}

icon_name() {
    code_value="$1"
    day_value="$2"
    case "$code_value" in
        0) [ "$day_value" = "0" ] && echo clear-night || echo clear ;;
        1) [ "$day_value" = "0" ] && echo clear-night || echo partly ;;
        2) [ "$day_value" = "0" ] && echo partly-night || echo partly ;;
        3) echo cloudy ;;
        45|48) echo fog ;;
        51|53|55|56|57|61|63|65|66|67|80|81|82) echo rain ;;
        71|73|75|77|85|86) echo snow ;;
        95|96|99) echo thunder ;;
        *) echo cloudy ;;
    esac
}

nth_line() {
    sed -n "${2}p" "$1" 2>/dev/null
}

round_temp() {
    value="$1"
    case "$value" in
        ''|--|*[!0-9.-]*) echo "$value" ;;
        *) awk -v v="$value" 'BEGIN { printf "%.0f", v }' ;;
    esac
}

format_precip() {
    awk -v v="$1" 'BEGIN {
        if (v !~ /^[0-9]+([.][0-9]+)?$/) v=0
        printf "%.1f", v + 0
    }'
}

format_percent() {
    awk -v v="$1" 'BEGIN {
        if (v !~ /^[0-9]+([.][0-9]+)?$/) v=0
        printf "%.0f", v + 0
    }'
}

hour_label() {
    hour="$(printf '%s\n' "$1" | sed 's/.*T\([0-9][0-9]\):.*/\1/')"
    case "$hour" in
        ''|*[!0-9]*) echo "--:--"; return ;;
    esac
    hour="${hour#0}"
    [ -n "$hour" ] || hour=0
    printf '%02d:00\n' "$hour"
}

clock_time() {
    printf '%s\n' "$1" | sed -n 's/.*T\([0-9][0-9]:[0-9][0-9]\).*/\1/p'
}

weekday_short() {
    printf '%s\n' "$1" | awk -F- '{
        y=$1+0; m=$2+0; d=$3+0
        if (m < 3) { m += 12; y -= 1 }
        k=y % 100; j=int(y / 100)
        h=(d + int(13 * (m + 1) / 5) + k + int(k / 4) + int(j / 4) + 5 * j) % 7
        split("SAT SUN MON TUE WED THU FRI", names, " ")
        print names[h + 1]
    }'
}

daypart_precip_total() {
    part_label="$1"
    day_offset="$2"
    case "$part_label" in
        MORNING) start_abs=$((day_offset * 24 + 7)); end_abs=$((day_offset * 24 + 12)) ;;
        AFTERNOON) start_abs=$((day_offset * 24 + 13)); end_abs=$((day_offset * 24 + 18)) ;;
        EVENING) start_abs=$((day_offset * 24 + 19)); end_abs=$((day_offset * 24 + 22)) ;;
        TONIGHT) start_abs=$((day_offset * 24 + 23)); end_abs=$(((day_offset + 1) * 24 + 6)) ;;
        *) echo "0.0"; return ;;
    esac

    total=0
    absolute_hour="$start_abs"
    while [ "$absolute_hour" -le "$end_abs" ]; do
        value="$(nth_line "${PARSE_PREFIX}.hprecip" "$((absolute_hour + 1))")"
        total="$(awk -v total="$total" -v value="$value" 'BEGIN {
            if (value !~ /^[0-9]+([.][0-9]+)?$/) value=0
            printf "%.4f", total + value
        }')"
        absolute_hour=$((absolute_hour + 1))
    done
    format_precip "$total"
}

set_forecast_slot() {
    prefix="$1"
    part_label="$2"
    day_offset="$3"
    target_hour="$4"
    target_hour_number="${target_hour#0}"
    [ -n "$target_hour_number" ] || target_hour_number=0
    item_number=$((day_offset * 24 + target_hour_number + 1))
    value="$(nth_line "${PARSE_PREFIX}.htemps" "$item_number")"
    code_value="$(nth_line "${PARSE_PREFIX}.hcodes" "$item_number")"
    day_value="$(nth_line "${PARSE_PREFIX}.hisday" "$item_number")"
    rain_value="$(nth_line "${PARSE_PREFIX}.hrain" "$item_number")"
    [ -n "$value" ] || value="--"
    [ -n "$code_value" ] || code_value=3
    case "$rain_value" in ''|null|*[!0-9]*) rain_value=0 ;; esac
    if [ -z "$day_value" ]; then
        case "$target_hour" in 08|8|15|19) day_value=1 ;; *) day_value=0 ;; esac
    fi
    eval "${prefix}_LABEL=\$part_label"
    eval "${prefix}_TEMP=\$(round_temp \"\$value\")"
    eval "${prefix}_ICON=\$(icon_name \"\$code_value\" \"\$day_value\")"
    eval "${prefix}_RAIN=\$rain_value"
    eval "${prefix}_PRECIP=\$(daypart_precip_total \"\$part_label\" \"\$day_offset\")"
}

build_daypart_slots() {
    slot_index=1
    day_offset=0
    while [ "$slot_index" -le 4 ]; do
        for slot in "08 MORNING" "15 AFTERNOON" "19 EVENING" "23 TONIGHT"; do
            slot_hour="${slot%% *}"
            slot_label="${slot#* }"
            slot_hour_number="${slot_hour#0}"
            if [ "$day_offset" -gt 0 ] || [ "$slot_hour_number" -ge "$HNOW" ]; then
                set_forecast_slot "P${slot_index}" "$slot_label" "$day_offset" "$slot_hour"
                slot_index=$((slot_index + 1))
                [ "$slot_index" -gt 4 ] && break
            fi
        done
        day_offset=$((day_offset + 1))
    done
}

cleanup_parse_files() {
    rm -f "${PARSE_PREFIX}.dmax" "${PARSE_PREFIX}.dmin" \
        "${PARSE_PREFIX}.ddates" "${PARSE_PREFIX}.dcodes" \
        "${PARSE_PREFIX}.sunrise" "${PARSE_PREFIX}.sunset" \
        "${PARSE_PREFIX}.dprecip" "${PARSE_PREFIX}.drain" \
        "${PARSE_PREFIX}.htimes" "${PARSE_PREFIX}.htemps" \
        "${PARSE_PREFIX}.hcodes" "${PARSE_PREFIX}.hisday" \
        "${PARSE_PREFIX}.hrain" "${PARSE_PREFIX}.hprecip"
}

parse_weather() {
    one_line="$(tr -d '\n' <"$1")"
    TEMP="$(printf '%s\n' "$one_line" | sed -n 's/.*"current":{[^}]*"temperature_2m":\([-0-9.][0-9.]*\).*/\1/p' | head -n 1)"
    FEELS="$(printf '%s\n' "$one_line" | sed -n 's/.*"current":{[^}]*"apparent_temperature":\([-0-9.][0-9.]*\).*/\1/p' | head -n 1)"
    CODE="$(printf '%s\n' "$one_line" | sed -n 's/.*"current":{[^}]*"weather_code":\([0-9][0-9]*\).*/\1/p' | head -n 1)"
    IS_DAY="$(printf '%s\n' "$one_line" | sed -n 's/.*"current":{[^}]*"is_day":\([0-9][0-9]*\).*/\1/p' | head -n 1)"
    daily_object="$(printf '%s\n' "$one_line" | awk 'match($0,/"daily":\{[^}]*\}/){print substr($0,RSTART,RLENGTH)}')"
    hourly_object="$(printf '%s\n' "$one_line" | awk 'match($0,/"hourly":\{[^}]*\}/){print substr($0,RSTART,RLENGTH)}')"

    printf '%s\n' "$daily_object" | sed -n 's/.*"temperature_2m_max":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >"${PARSE_PREFIX}.dmax"
    printf '%s\n' "$daily_object" | sed -n 's/.*"temperature_2m_min":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >"${PARSE_PREFIX}.dmin"
    printf '%s\n' "$daily_object" | sed -n 's/.*"time":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' | tr -d '"' >"${PARSE_PREFIX}.ddates"
    printf '%s\n' "$daily_object" | sed -n 's/.*"weather_code":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >"${PARSE_PREFIX}.dcodes"
    printf '%s\n' "$daily_object" | sed -n 's/.*"sunrise":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' | tr -d '"' >"${PARSE_PREFIX}.sunrise"
    printf '%s\n' "$daily_object" | sed -n 's/.*"sunset":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' | tr -d '"' >"${PARSE_PREFIX}.sunset"
    printf '%s\n' "$daily_object" | sed -n 's/.*"precipitation_sum":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >"${PARSE_PREFIX}.dprecip"
    printf '%s\n' "$daily_object" | sed -n 's/.*"precipitation_probability_max":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >"${PARSE_PREFIX}.drain"
    printf '%s\n' "$hourly_object" | sed -n 's/.*"time":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' | tr -d '"' >"${PARSE_PREFIX}.htimes"
    printf '%s\n' "$hourly_object" | sed -n 's/.*"temperature_2m":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >"${PARSE_PREFIX}.htemps"
    printf '%s\n' "$hourly_object" | sed -n 's/.*"weather_code":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >"${PARSE_PREFIX}.hcodes"
    printf '%s\n' "$hourly_object" | sed -n 's/.*"is_day":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >"${PARSE_PREFIX}.hisday"
    printf '%s\n' "$hourly_object" | sed -n 's/.*"precipitation_probability":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >"${PARSE_PREFIX}.hrain"
    printf '%s\n' "$hourly_object" | sed -n 's/.*"precipitation":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >"${PARSE_PREFIX}.hprecip"

    HIGH="$(nth_line "${PARSE_PREFIX}.dmax" 1)"
    LOW="$(nth_line "${PARSE_PREFIX}.dmin" 1)"
    SUNRISE="$(clock_time "$(nth_line "${PARSE_PREFIX}.sunrise" 1)")"
    SUNSET="$(clock_time "$(nth_line "${PARSE_PREFIX}.sunset" 1)")"
    [ -n "$TEMP" ] || TEMP="--"
    [ -n "$FEELS" ] || FEELS="$TEMP"
    [ -n "$HIGH" ] || HIGH="--"
    [ -n "$LOW" ] || LOW="--"
    [ -n "$CODE" ] || CODE=3
    [ -n "$SUNRISE" ] || SUNRISE="--:--"
    [ -n "$SUNSET" ] || SUNSET="--:--"
    CONDITION="$(condition_text "$CODE")"
    ICON="$(icon_name "$CODE" "$IS_DAY")"

    HNOW="$(date '+%H')"
    HNOW="${HNOW#0}"
    [ -n "$HNOW" ] || HNOW=0
    base_index=$((HNOW + 1))
    CURRENT_RAIN="$(nth_line "${PARSE_PREFIX}.hrain" "$base_index")"
    case "$CURRENT_RAIN" in ''|null|*[!0-9]*) CURRENT_RAIN=0 ;; esac
    CURRENT_PRECIP="$(format_precip "$(nth_line "${PARSE_PREFIX}.hprecip" "$base_index")")"

    index=1
    while [ "$index" -le 4 ]; do
        item_number=$((base_index + index))
        time_value="$(nth_line "${PARSE_PREFIX}.htimes" "$item_number")"
        code_value="$(nth_line "${PARSE_PREFIX}.hcodes" "$item_number")"
        temp_value="$(nth_line "${PARSE_PREFIX}.htemps" "$item_number")"
        day_value="$(nth_line "${PARSE_PREFIX}.hisday" "$item_number")"
        rain_value="$(nth_line "${PARSE_PREFIX}.hrain" "$item_number")"
        precip_value="$(nth_line "${PARSE_PREFIX}.hprecip" "$item_number")"
        case "$rain_value" in ''|null|*[!0-9]*) rain_value=0 ;; esac
        eval "H${index}_LABEL=\$(hour_label \"\$time_value\")"
        eval "H${index}_TEMP=\$(round_temp \"\$temp_value\")"
        eval "H${index}_ICON=\$(icon_name \"\$code_value\" \"\$day_value\")"
        eval "H${index}_RAIN=\$rain_value"
        eval "H${index}_PRECIP=\$(format_precip \"\$precip_value\")"
        index=$((index + 1))
    done

    build_daypart_slots

    index=1
    while [ "$index" -le 4 ]; do
        item_number=$((index + 1))
        date_value="$(nth_line "${PARSE_PREFIX}.ddates" "$item_number")"
        high_value="$(nth_line "${PARSE_PREFIX}.dmax" "$item_number")"
        low_value="$(nth_line "${PARSE_PREFIX}.dmin" "$item_number")"
        code_value="$(nth_line "${PARSE_PREFIX}.dcodes" "$item_number")"
        precip_value="$(nth_line "${PARSE_PREFIX}.dprecip" "$item_number")"
        rain_value="$(format_percent "$(nth_line "${PARSE_PREFIX}.drain" "$item_number")")"
        [ -n "$high_value" ] || high_value="--"
        [ -n "$low_value" ] || low_value="--"
        [ -n "$code_value" ] || code_value=3
        [ -n "$date_value" ] && day_label="$(weekday_short "$date_value")" || day_label="---"
        eval "D${index}_LABEL=\$day_label"
        eval "D${index}_HIGH=\$(round_temp \"\$high_value\")"
        eval "D${index}_LOW=\$(round_temp \"\$low_value\")"
        eval "D${index}_ICON=\$(icon_name \"\$code_value\" 1)"
        eval "D${index}_MM=\$(format_precip \"\$precip_value\")"
        eval "D${index}_RAIN=\$rain_value"
        index=$((index + 1))
    done

    TEMP="$(round_temp "$TEMP")"
    FEELS="$(round_temp "$FEELS")"
    HIGH="$(round_temp "$HIGH")"
    LOW="$(round_temp "$LOW")"
    cleanup_parse_files
}

weather_location_key() {
    printf '%s|%s|%s' "$LATITUDE" "$LONGITUDE" "$TIMEZONE"
}

weather_cache_matches() {
    [ -s "$WEATHER_CACHE" ] && [ -f "$WEATHER_CACHE_LOCATION" ] || return 1
    IFS= read -r cached_weather_location <"$WEATHER_CACHE_LOCATION" || return 1
    [ "$cached_weather_location" = "$(weather_location_key)" ]
}

save_weather_cache() {
    cache_new="${WEATHER_CACHE}.new"
    location_new="${WEATHER_CACHE_LOCATION}.new"
    updated_new="${WEATHER_CACHE_UPDATED}.new"
    cp "$WEATHER_TMP" "$cache_new" 2>/dev/null || return 1
    weather_location_key >"$location_new" 2>/dev/null || return 1
    date '+%Y-%m-%d %H:%M' >"$updated_new" 2>/dev/null || return 1
    mv "$cache_new" "$WEATHER_CACHE" 2>/dev/null || return 1
    mv "$location_new" "$WEATHER_CACHE_LOCATION" 2>/dev/null || return 1
    mv "$updated_new" "$WEATHER_CACHE_UPDATED" 2>/dev/null || return 1
}

set_offline_weather() {
    FETCH_STATE=OFFLINE
    WEATHER_UPDATED="unavailable"
    TEMP="--"
    FEELS="--"
    HIGH="--"
    LOW="--"
    CODE=3
    CONDITION=Offline
    ICON=cloudy
    CURRENT_RAIN=0
    CURRENT_PRECIP="0.0"
    SUNRISE="--:--"
    SUNSET="--:--"
    for index in 1 2 3 4; do
        eval "H${index}_LABEL=--:--"
        eval "H${index}_TEMP=--"
        eval "H${index}_ICON=cloudy"
        eval "H${index}_RAIN=0"
        eval "H${index}_PRECIP=0.0"
        eval "P${index}_LABEL=---"
        eval "P${index}_TEMP=--"
        eval "P${index}_ICON=cloudy"
        eval "P${index}_RAIN=0"
        eval "P${index}_PRECIP=0.0"
        eval "D${index}_LABEL=---"
        eval "D${index}_HIGH=--"
        eval "D${index}_LOW=--"
        eval "D${index}_ICON=cloudy"
        eval "D${index}_MM=0.0"
        eval "D${index}_RAIN=0"
    done
}

fetch_weather() {
    if ! resolve_location; then
        scribe_log "weather_fetch_skipped=location_unresolved"
        set_offline_weather
        return 1
    fi

    timezone_url="$(printf '%s' "$TIMEZONE" | sed 's/+/%2B/g; s|/|%2F|g')"
    WEATHER_URL="https://api.open-meteo.com/v1/forecast?latitude=${LATITUDE}&longitude=${LONGITUDE}&current=temperature_2m,apparent_temperature,weather_code,is_day&hourly=temperature_2m,weather_code,is_day,precipitation_probability,precipitation&daily=temperature_2m_max,temperature_2m_min,weather_code,precipitation_sum,precipitation_probability_max,sunrise,sunset&timezone=${timezone_url}&precipitation_unit=mm&forecast_days=5&models=dwd_icon_seamless"

    rm -f "$WEATHER_TMP"
    scribe_log "request_start=true endpoint=https://api.open-meteo.com/v1/forecast model=dwd_icon_seamless"
    "$XH" -d -q -o "$WEATHER_TMP" get "$WEATHER_URL" >>"$SCRIBE_LOG_FILE" 2>&1
    HTTP_RETURN_CODE=$?
    DOWNLOADED_BYTES=0
    [ -f "$WEATHER_TMP" ] && DOWNLOADED_BYTES="$(wc -c <"$WEATHER_TMP")"
    scribe_log "http_client_return_code=$HTTP_RETURN_CODE"
    scribe_log "downloaded_byte_count=$DOWNLOADED_BYTES"

    if [ "$HTTP_RETURN_CODE" -eq 0 ] && [ -s "$WEATHER_TMP" ]; then
        if save_weather_cache; then
            scribe_log "weather_cache_updated=true"
        else
            scribe_log "weather_cache_updated=false"
        fi
        FETCH_STATE=LIVE
        WEATHER_UPDATED="$(date '+%H:%M')"
        parse_weather "$WEATHER_TMP"
        return 0
    fi

    if weather_cache_matches; then
        FETCH_STATE=CACHED
        if [ -s "$WEATHER_CACHE_UPDATED" ]; then
            IFS= read -r WEATHER_UPDATED <"$WEATHER_CACHE_UPDATED"
        else
            WEATHER_UPDATED="cached"
        fi
        parse_weather "$WEATHER_CACHE"
        return 1
    fi

    scribe_log "weather_cache_available=false"
    set_offline_weather
    return 1
}
