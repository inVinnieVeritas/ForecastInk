#!/bin/sh

# Scribe-native 1860x2480 portrait dashboard renderer.
SCRIBE_UI_WIDTH=1860
SCRIBE_UI_HEIGHT=2480
SCRIBE_UI_REGULAR_FONT=""
SCRIBE_UI_BOLD_FONT=""
SCRIBE_UI_CAPABILITY_ERROR=""

scribe_ui_use_font_pair() {
    regular_candidate="$1"
    bold_candidate="$2"
    if [ -r "$regular_candidate" ] && [ -r "$bold_candidate" ]; then
        SCRIBE_UI_REGULAR_FONT="$regular_candidate"
        SCRIBE_UI_BOLD_FONT="$bold_candidate"
        return 0
    fi
    return 1
}

scribe_ui_select_fonts() {
    SCRIBE_UI_REGULAR_FONT=""
    SCRIBE_UI_BOLD_FONT=""

    scribe_ui_use_font_pair \
        "/usr/java/lib/fonts/Helvetica_LT_65_Medium.ttf" \
        "/usr/java/lib/fonts/Helvetica_LT_75_Bold.ttf" ||
    scribe_ui_use_font_pair \
        "/usr/java/lib/fonts/HelveticaNeueLTStd-Roman.ttf" \
        "/usr/java/lib/fonts/HelveticaNeueLTStd-Bd.ttf" ||
    scribe_ui_use_font_pair \
        "/usr/java/lib/fonts/Futura_LT_65_Medium.ttf" \
        "/usr/java/lib/fonts/Futura_LT_75_Bold.ttf" ||
    scribe_ui_use_font_pair \
        "/usr/java/lib/fonts/Caecilia_LT_65_Medium.ttf" \
        "/usr/java/lib/fonts/Caecilia_LT_75_Bold.ttf" || true

    if [ -z "$SCRIBE_UI_REGULAR_FONT" ]; then
        for regular_candidate in \
            "/usr/java/lib/fonts/HelveticaNeueLTStd-Md.ttf" \
            "/usr/java/lib/fonts/Caecilia_LT_65_Medium.ttf" \
            "/usr/java/lib/fonts/Futura_LT_65_Medium.ttf"
        do
            [ -r "$regular_candidate" ] || continue
            SCRIBE_UI_REGULAR_FONT="$regular_candidate"
            break
        done
    fi

    if [ -z "$SCRIBE_UI_BOLD_FONT" ]; then
        for bold_candidate in \
            "/usr/java/lib/fonts/HelveticaNeueLTStd-Bold.ttf" \
            "/usr/java/lib/fonts/Caecilia_LT_75_Bold.ttf" \
            "/usr/java/lib/fonts/Futura_LT_75_Bold.ttf"
        do
            [ -r "$bold_candidate" ] || continue
            SCRIBE_UI_BOLD_FONT="$bold_candidate"
            break
        done
    fi

    [ -n "$SCRIBE_UI_REGULAR_FONT" ] || return 1
    [ -n "$SCRIBE_UI_BOLD_FONT" ] || SCRIBE_UI_BOLD_FONT="$SCRIBE_UI_REGULAR_FONT"
    return 0
}

scribe_ui_prepare() {
    SCRIBE_UI_CAPABILITY_ERROR=""

    if ! scribe_ui_select_fonts; then
        SCRIBE_UI_CAPABILITY_ERROR="No readable Kindle system font pair"
        scribe_log "selected_regular_font=unavailable"
        scribe_log "selected_bold_font=unavailable"
        scribe_log "opentype_capability=not_tested"
        scribe_log "image_capability=not_tested"
        return 1
    fi

    scribe_log "selected_regular_font=$SCRIBE_UI_REGULAR_FONT"
    scribe_log "selected_bold_font=$SCRIBE_UI_BOLD_FONT"

    fbink_help="$("$SCRIBE_FBINK" --help 2>&1)"
    fbink_help_return_code=$?
    scribe_log "fbink_help_return_code=$fbink_help_return_code"

    if ! printf '%s\n' "$fbink_help" | grep -q -e '--truetype'; then
        SCRIBE_UI_CAPABILITY_ERROR="FBInk OpenType support unavailable"
        scribe_log "opentype_capability=unavailable"
        scribe_log "image_capability=not_tested"
        return 1
    fi

    "$SCRIBE_FBINK" -q -l \
        -t regular="$SCRIBE_UI_REGULAR_FONT",bold="$SCRIBE_UI_BOLD_FONT",px=48,top=0,bottom=2300,left=0,right=0,style=REGULAR,compute \
        "ForecastInk" >>"$SCRIBE_LOG_FILE" 2>&1
    opentype_probe_return_code=$?
    scribe_log "opentype_probe_return_code=$opentype_probe_return_code"
    if [ "$opentype_probe_return_code" -ne 0 ]; then
        SCRIBE_UI_CAPABILITY_ERROR="FBInk OpenType compute probe failed"
        scribe_log "opentype_capability=failed"
        scribe_log "image_capability=not_tested"
        return 1
    fi
    scribe_log "opentype_capability=available"

    if ! printf '%s\n' "$fbink_help" | grep -q -e '--image'; then
        SCRIBE_UI_CAPABILITY_ERROR="FBInk PNG image support unavailable"
        scribe_log "image_capability=unavailable"
        return 1
    fi
    scribe_log "image_capability=advertised"
    return 0
}

scribe_ui_icon_path() {
    icon_group="$1"
    icon_name_value="$2"
    case "$icon_name_value" in
        clear|clear-night|partly|partly-night|cloudy|fog|rain|snow|thunder) ;;
        *) icon_name_value="cloudy" ;;
    esac
    icon_path="./assets/$icon_group/${icon_name_value}.png"
    [ -r "$icon_path" ] || icon_path="./assets/$icon_group/cloudy.png"
    printf '%s\n' "$icon_path"
}

scribe_ui_draw_text() {
    draw_label="$1"
    text_size="$2"
    text_top="$3"
    text_height="$4"
    text_left="$5"
    text_width="$6"
    text_style="$7"
    text_alignment="$8"
    shift 8
    text_bottom=$((SCRIBE_UI_HEIGHT - text_top - text_height))
    text_right=$((SCRIBE_UI_WIDTH - text_left - text_width))

    if [ "$text_alignment" = "CENTER" ]; then
        "$SCRIBE_FBINK" -q -b -m -C BLACK -B WHITE \
            -t regular="$SCRIBE_UI_REGULAR_FONT",bold="$SCRIBE_UI_BOLD_FONT",px="$text_size",top="$text_top",bottom="$text_bottom",left="$text_left",right="$text_right",style="$text_style" \
            "$*" >>"$SCRIBE_LOG_FILE" 2>&1
    else
        "$SCRIBE_FBINK" -q -b -C BLACK -B WHITE \
            -t regular="$SCRIBE_UI_REGULAR_FONT",bold="$SCRIBE_UI_BOLD_FONT",px="$text_size",top="$text_top",bottom="$text_bottom",left="$text_left",right="$text_right",style="$text_style" \
            "$*" >>"$SCRIBE_LOG_FILE" 2>&1
    fi
    draw_return_code=$?
    scribe_log "text_render label=$draw_label return_code=$draw_return_code"
    return "$draw_return_code"
}

scribe_ui_draw_image() {
    image_label="$1"
    image_path="$2"
    image_x="$3"
    image_y="$4"
    image_width="$5"
    image_height="$6"

    scribe_log "icon_asset label=$image_label path=$image_path"
    "$SCRIBE_FBINK" -q -b \
        -g file="$image_path",x="$image_x",y="$image_y",w="$image_width",h="$image_height" \
        >>"$SCRIBE_LOG_FILE" 2>&1
    image_return_code=$?
    scribe_log "image_render label=$image_label return_code=$image_return_code"
    return "$image_return_code"
}

scribe_ui_draw_hour() {
    hour_index="$1"
    column_left="$2"
    eval "hour_value=\$H${hour_index}_LABEL"
    eval "hour_temp=\$H${hour_index}_TEMP"
    eval "hour_icon=\$H${hour_index}_ICON"
    eval "hour_rain=\$H${hour_index}_RAIN"
    eval "hour_precip=\$H${hour_index}_PRECIP"
    hour_icon_path="$(scribe_ui_icon_path weather "$hour_icon")"

    scribe_ui_draw_text "hour_${hour_index}_time" 50 1570 70 "$column_left" 360 BOLD CENTER "$hour_value" || return 1
    scribe_ui_draw_image "hour_${hour_index}_icon" "$hour_icon_path" "$((column_left + 70))" 1660 220 220 || return 1
    scribe_ui_draw_text "hour_${hour_index}_temperature" 74 1905 100 "$column_left" 360 BOLD CENTER "${hour_temp}°" || return 1
    scribe_ui_draw_text "hour_${hour_index}_rain" 39 2025 60 "$column_left" 360 REGULAR CENTER "${hour_rain}% / ${hour_precip} mm" || return 1
}

scribe_ui_render_dashboard() {
    dashboard_location="$1"
    dashboard_date="$2"
    hero_icon_path="$(scribe_ui_icon_path hero "$ICON")"

    "$SCRIBE_FBINK" -q -b -B WHITE -k >>"$SCRIBE_LOG_FILE" 2>&1
    clear_return_code=$?
    scribe_log "canvas_clear_return_code=$clear_return_code"
    [ "$clear_return_code" -eq 0 ] || return "$clear_return_code"

    scribe_ui_draw_text title 58 60 80 120 1620 REGULAR LEFT "ForecastInk" || return 1
    scribe_ui_draw_text location 96 165 125 120 1620 BOLD LEFT "$dashboard_location" || return 1
    scribe_ui_draw_text date 46 305 70 120 1620 REGULAR LEFT "$dashboard_date" || return 1

    scribe_ui_draw_image current_weather "$hero_icon_path" 120 470 520 520 || {
        scribe_log "image_capability=failed"
        return 1
    }
    scribe_log "image_capability=available"
    scribe_ui_draw_text current_temperature 220 430 285 710 1030 BOLD LEFT "${TEMP}°C" || return 1
    scribe_ui_draw_text current_condition 76 715 95 710 1030 BOLD LEFT "$CONDITION" || return 1
    scribe_ui_draw_text feels_like 52 825 70 710 1030 REGULAR LEFT "Feels like ${FEELS}°C" || return 1
    scribe_ui_draw_text high_low 52 920 70 710 1030 REGULAR LEFT "High ${HIGH}°   Low ${LOW}°" || return 1

    scribe_ui_draw_text rain_label 38 1110 55 120 360 REGULAR CENTER "RAIN CHANCE" || return 1
    scribe_ui_draw_image rain_probability "./assets/ui/rain-probability.png" 264 1180 72 72 || return 1
    scribe_ui_draw_text rain_value 58 1270 75 120 360 BOLD CENTER "${CURRENT_RAIN}%" || return 1

    scribe_ui_draw_text precip_label 38 1110 55 525 360 REGULAR CENTER "PRECIPITATION" || return 1
    scribe_ui_draw_text precip_value 58 1235 85 525 360 BOLD CENTER "${CURRENT_PRECIP} mm" || return 1

    scribe_ui_draw_text sunrise_label 38 1110 55 930 360 REGULAR CENTER "SUNRISE" || return 1
    scribe_ui_draw_image sunrise "./assets/ui/sunrise.png" 1074 1180 72 48 || return 1
    scribe_ui_draw_text sunrise_value 58 1270 75 930 360 BOLD CENTER "$SUNRISE" || return 1

    scribe_ui_draw_text sunset_label 38 1110 55 1335 360 REGULAR CENTER "SUNSET" || return 1
    scribe_ui_draw_image sunset "./assets/ui/sunset.png" 1479 1180 72 48 || return 1
    scribe_ui_draw_text sunset_value 58 1270 75 1335 360 BOLD CENTER "$SUNSET" || return 1

    scribe_ui_draw_text next_hours_title 54 1450 75 120 1620 BOLD LEFT "NEXT FOUR HOURS" || return 1
    scribe_ui_draw_hour 1 120 || return 1
    scribe_ui_draw_hour 2 525 || return 1
    scribe_ui_draw_hour 3 930 || return 1
    scribe_ui_draw_hour 4 1335 || return 1

    scribe_ui_draw_text fetch_state 48 2265 65 120 760 BOLD LEFT "$FETCH_STATE" || return 1
    scribe_ui_draw_text updated 40 2275 60 930 810 REGULAR CENTER "Updated $WEATHER_UPDATED" || return 1

    "$SCRIBE_FBINK" -q -w -s >>"$SCRIBE_LOG_FILE" 2>&1
    refresh_return_code=$?
    scribe_log "screen_refresh_return_code=$refresh_return_code"
    return "$refresh_return_code"
}

scribe_ui_render_capability_failure() {
    failure_reason="$1"
    failure_message="$(printf 'ForecastInk Scribe UI capability test\n\n%s\n\nSee /mnt/us/ForecastInk/logs/scribe-dev.log' "$failure_reason")"
    "$SCRIBE_FBINK" -q -c -m -M -w -S 5 -C BLACK -B WHITE -- "$failure_message" >>"$SCRIBE_LOG_FILE" 2>&1
}
