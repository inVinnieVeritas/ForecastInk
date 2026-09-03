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

scribe_ui_draw_rule() {
    rule_x="$1"
    rule_y="$2"
    rule_width="$3"
    rule_height="$4"
    "$SCRIBE_FBINK" -q -b \
        -g file="./assets/ui/black.png",x="$rule_x",y="$rule_y",w="$rule_width",h="$rule_height" \
        >>"$SCRIBE_LOG_FILE" 2>&1
}

scribe_ui_draw_box() {
    box_x="$1"
    box_y="$2"
    box_width="$3"
    box_height="$4"
    scribe_ui_draw_rule "$box_x" "$box_y" "$box_width" 3 || return 1
    scribe_ui_draw_rule "$box_x" "$((box_y + box_height - 3))" "$box_width" 3 || return 1
    scribe_ui_draw_rule "$box_x" "$box_y" 3 "$box_height" || return 1
    scribe_ui_draw_rule "$((box_x + box_width - 3))" "$box_y" 3 "$box_height" || return 1
}

scribe_ui_is_zero() {
    case "$1" in
        ''|0|0.0|0.00|0.000) return 0 ;;
        *) return 1 ;;
    esac
}

scribe_ui_precip_amount_text() {
    case "$1" in
        '<0.1') printf '%s\n' '<0.1 mm' ;;
        ''|0|0.0|0.00|0.000) printf '%s\n' '0 mm' ;;
        *) printf '%s mm\n' "$1" ;;
    esac
}

scribe_ui_battery_percent() {
    for battery_capacity_file in /sys/class/power_supply/*/capacity; do
        [ -r "$battery_capacity_file" ] || continue
        IFS= read -r battery_capacity_value <"$battery_capacity_file"
        case "$battery_capacity_value" in
            ''|*[!0-9]*) continue ;;
        esac
        if [ "$battery_capacity_value" -ge 0 ] 2>/dev/null &&
            [ "$battery_capacity_value" -le 100 ] 2>/dev/null; then
            printf '%s\n' "$battery_capacity_value"
            return 0
        fi
    done
    printf '%s\n' "--"
    return 1
}

scribe_ui_draw_battery() {
    battery_percent="$(scribe_ui_battery_percent)"
    scribe_log "battery_percent=$battery_percent"
    scribe_ui_draw_rule 1580 55 54 3 || return 1
    scribe_ui_draw_rule 1580 80 54 3 || return 1
    scribe_ui_draw_rule 1580 55 3 28 || return 1
    scribe_ui_draw_rule 1631 55 3 28 || return 1
    scribe_ui_draw_rule 1634 63 6 12 || return 1

    case "$battery_percent" in
        ''|*[!0-9]*) ;;
        *)
            battery_fill_width="$((battery_percent * 46 / 100))"
            if [ "$battery_fill_width" -gt 0 ]; then
                scribe_ui_draw_rule 1585 60 "$battery_fill_width" 18 || return 1
            fi
            ;;
    esac
    scribe_ui_draw_text battery_value 38 43 58 1650 100 REGULAR LEFT "${battery_percent}%" || return 1
}

scribe_ui_draw_forecast_rain() {
    forecast_rain_label="$1"
    forecast_rain_probability="$2"
    forecast_rain_precip="$3"
    forecast_rain_left="$4"
    forecast_rain_top="$5"
    forecast_rain_icon_size="$6"
    forecast_rain_probability_size="$7"
    forecast_rain_precip_size="$8"
    forecast_rain_width="$9"

    if scribe_ui_is_zero "$forecast_rain_probability" && scribe_ui_is_zero "$forecast_rain_precip"; then
        scribe_log "rain_render label=$forecast_rain_label state=omitted_zero"
        return 0
    fi

    forecast_rain_amount_text="$(scribe_ui_precip_amount_text "$forecast_rain_precip")"
    forecast_rain_center="$((forecast_rain_left + forecast_rain_width / 2))"
    forecast_rain_icon_left="$((forecast_rain_center - forecast_rain_icon_size - 7))"
    forecast_rain_probability_left="$((forecast_rain_center + 7))"
    forecast_rain_probability_width="$((forecast_rain_width / 2 - 7))"
    scribe_ui_draw_image "${forecast_rain_label}_rain_icon" "./assets/ui/rain-probability.png" \
        "$forecast_rain_icon_left" "$forecast_rain_top" "$forecast_rain_icon_size" "$forecast_rain_icon_size" || return 1
    scribe_ui_draw_text "${forecast_rain_label}_rain" "$forecast_rain_probability_size" "$((forecast_rain_top - 4))" \
        "$((forecast_rain_icon_size + 8))" "$forecast_rain_probability_left" "$forecast_rain_probability_width" BOLD LEFT \
        "${forecast_rain_probability}%" || return 1
    scribe_ui_draw_text "${forecast_rain_label}_precip" "$forecast_rain_precip_size" \
        "$((forecast_rain_top + forecast_rain_icon_size + 4))" "$((forecast_rain_precip_size + 10))" \
        "$forecast_rain_left" "$forecast_rain_width" REGULAR CENTER \
        "$forecast_rain_amount_text" || return 1
}

scribe_ui_draw_current_rain() {
    if scribe_ui_is_zero "$CURRENT_RAIN" && scribe_ui_is_zero "$CURRENT_PRECIP"; then
        scribe_log "rain_render label=current state=omitted_zero"
        return 0
    fi

    current_precip_text="$(scribe_ui_precip_amount_text "$CURRENT_PRECIP")"
    scribe_ui_draw_image rain_probability "./assets/ui/rain-probability.png" 1230 708 54 54 || return 1
    scribe_ui_draw_text rain_value 52 700 66 1298 120 BOLD LEFT "${CURRENT_RAIN}%" || return 1
    scribe_ui_draw_rule 1435 708 3 54 || return 1
    scribe_ui_draw_text precip_value 52 700 66 1462 250 REGULAR LEFT "$current_precip_text" || return 1
}

scribe_ui_draw_hour_column() {
    hour_index="$1"
    column_left="$2"
    eval "hour_value=\$H${hour_index}_LABEL"
    eval "hour_temp=\$H${hour_index}_TEMP"
    eval "hour_icon=\$H${hour_index}_ICON"
    eval "hour_rain=\$H${hour_index}_RAIN"
    eval "hour_precip=\$H${hour_index}_PRECIP"
    hour_icon_path="$(scribe_ui_icon_path weather "$hour_icon")"

    scribe_ui_draw_text "hour_${hour_index}_time" 34 995 43 "$column_left" 205 BOLD CENTER "$hour_value" || return 1
    scribe_ui_draw_image "hour_${hour_index}_icon" "$hour_icon_path" "$((column_left + 36))" 1048 132 112 || return 1
    scribe_ui_draw_text "hour_${hour_index}_temperature" 52 1169 61 "$column_left" 205 BOLD CENTER "${hour_temp}°" || return 1
    scribe_ui_draw_forecast_rain "hour_${hour_index}" "$hour_rain" "$hour_precip" "$column_left" 1232 30 28 24 205 || return 1
}

scribe_ui_daypart_display_label() {
    daypart_raw_label="$1"
    case "$daypart_raw_label" in
        TONIGHT|MORNING|AFTERNOON|EVENING) printf '%s\n' "$daypart_raw_label" ;;
        *) printf '%s\n' "$daypart_raw_label" ;;
    esac
}

scribe_ui_draw_daypart_rain() {
    daypart_rain_label="$1"
    daypart_rain_probability="$2"
    daypart_rain_precip="$3"
    daypart_rain_left="$4"
    daypart_rain_top="$5"
    daypart_rain_width="$6"
    daypart_rain_center="$((daypart_rain_left + daypart_rain_width / 2))"

    if scribe_ui_is_zero "$daypart_rain_probability" && scribe_ui_is_zero "$daypart_rain_precip"; then
        scribe_log "rain_render label=$daypart_rain_label state=omitted_zero"
        return 0
    fi

    daypart_rain_amount_text="$(scribe_ui_precip_amount_text "$daypart_rain_precip")"
    scribe_ui_draw_image "${daypart_rain_label}_rain_icon" "./assets/ui/rain-probability.png" \
        "$((daypart_rain_center - 145))" "$daypart_rain_top" 34 34 || return 1
    scribe_ui_draw_text "${daypart_rain_label}_rain" 32 "$((daypart_rain_top - 4))" 42 \
        "$((daypart_rain_center - 101))" 82 BOLD LEFT "${daypart_rain_probability}%" || return 1
    scribe_ui_draw_rule "$((daypart_rain_center - 5))" "$daypart_rain_top" 3 34 || return 1
    scribe_ui_draw_text "${daypart_rain_label}_precip" 26 "$((daypart_rain_top - 1))" 38 \
        "$((daypart_rain_center + 20))" 125 REGULAR LEFT "$daypart_rain_amount_text" || return 1
}

scribe_ui_draw_daypart_column() {
    daypart_index="$1"
    column_left="$2"
    eval "daypart_label=\$P${daypart_index}_LABEL"
    eval "daypart_day_offset=\$P${daypart_index}_DAY_OFFSET"
    eval "daypart_time=\$P${daypart_index}_TIME"
    eval "daypart_condition=\$P${daypart_index}_CONDITION"
    eval "daypart_temp=\$P${daypart_index}_TEMP"
    eval "daypart_icon=\$P${daypart_index}_ICON"
    eval "daypart_rain=\$P${daypart_index}_RAIN"
    eval "daypart_precip=\$P${daypart_index}_PRECIP"
    daypart_icon_path="$(scribe_ui_icon_path weather "$daypart_icon")"
    daypart_display_label="$(scribe_ui_daypart_display_label "$daypart_label" "$daypart_day_offset")"

    scribe_ui_draw_text "daypart_${daypart_index}_label" 42 1426 52 "$column_left" 410 BOLD CENTER "$daypart_display_label" || return 1
    scribe_ui_draw_text "daypart_${daypart_index}_time" 34 1474 42 "$column_left" 410 REGULAR CENTER "$daypart_time" || return 1
    scribe_ui_draw_image "daypart_${daypart_index}_icon" "$daypart_icon_path" "$((column_left + 115))" 1518 180 130 || return 1
    scribe_ui_draw_text "daypart_${daypart_index}_condition" 36 1652 44 "$column_left" 410 REGULAR CENTER "$daypart_condition" || return 1
    scribe_ui_draw_text "daypart_${daypart_index}_temperature" 60 1694 68 "$column_left" 410 BOLD CENTER "${daypart_temp}°" || return 1
    scribe_ui_draw_daypart_rain "daypart_${daypart_index}" "$daypart_rain" "$daypart_precip" "$column_left" 1768 410 || return 1
}

scribe_ui_draw_day_column() {
    day_index="$1"
    column_left="$2"
    column_width="$3"
    eval "day_label=\$D${day_index}_LABEL"
    eval "day_high=\$D${day_index}_HIGH"
    eval "day_low=\$D${day_index}_LOW"
    eval "day_icon=\$D${day_index}_ICON"
    eval "day_amount=\$D${day_index}_MM"
    eval "day_rain=\$D${day_index}_RAIN"
    day_icon_path="$(scribe_ui_icon_path weather "$day_icon")"

    day_icon_left="$((column_left + (column_width - 156) / 2))"
    scribe_ui_draw_text "day_${day_index}_label" 36 1910 44 "$column_left" "$column_width" BOLD CENTER "$day_label" || return 1
    scribe_ui_draw_image "day_${day_index}_icon" "$day_icon_path" "$day_icon_left" 1965 156 130 || return 1
    scribe_ui_draw_text "day_${day_index}_high_low" 40 2102 48 "$column_left" "$column_width" BOLD CENTER "${day_high}° / ${day_low}°" || return 1
    scribe_ui_draw_forecast_rain "day_${day_index}" "$day_rain" "$day_amount" "$column_left" 2160 30 28 28 "$column_width" || return 1
}

scribe_ui_render_header() {
    header_date="$(date '+%A, %d %B' | sed 's/, 0/, /')"
    scribe_ui_draw_text header_date 42 43 58 110 1120 BOLD LEFT "$header_date" || return 1
    scribe_ui_draw_battery || return 1
    scribe_ui_draw_rule 110 128 1640 3 || return 1
}

scribe_ui_render_current_card() {
    current_location="$1"
    hero_icon_path="$(scribe_ui_icon_path hero "$ICON")"
    hero_location="$(printf '%s\n' "$current_location" | tr '[:lower:]' '[:upper:]')"
    hero_scheduled_time="$(date '+%H:00')"
    scribe_log "top_card_layout=icon-polish-009"
    scribe_log "hero_scheduled_time=$hero_scheduled_time"
    scribe_ui_draw_text location 72 172 90 110 650 BOLD LEFT "$hero_location" || return 1
    scribe_ui_draw_image current_weather "$hero_icon_path" 15 245 580 455 || return 1
    scribe_ui_draw_image sunrise "./assets/ui/sunrise.png" 108 716 80 54 || return 1
    scribe_ui_draw_text sunrise_value 44 713 60 205 500 REGULAR LEFT "Sunrise  $SUNRISE" || return 1
    scribe_ui_draw_image sunset "./assets/ui/sunset.png" 108 784 80 54 || return 1
    scribe_ui_draw_text sunset_value 44 781 60 205 500 REGULAR LEFT "Sunset  $SUNSET" || return 1
    scribe_ui_draw_text hero_clock 110 165 145 900 780 BOLD LEFT "$hero_scheduled_time" || return 1
    scribe_ui_draw_text current_temperature 285 298 300 880 870 BOLD LEFT "${TEMP}°C" || return 1
    scribe_ui_draw_text current_condition 86 588 100 910 800 BOLD LEFT "$CONDITION" || return 1
    scribe_ui_draw_text feels_like 52 700 66 910 300 REGULAR LEFT "Feels ${FEELS}°C" || return 1
    scribe_ui_draw_current_rain || return 1
    scribe_ui_draw_text high_low 54 790 66 920 790 BOLD LEFT "High ${HIGH}° / Low ${LOW}°" || return 1
}

scribe_ui_render_hourly_card() {
    scribe_ui_draw_text hours_heading 40 920 48 110 1640 BOLD LEFT "NEXT 8 HOURS" || return 1
    scribe_ui_draw_rule 110 972 1640 3 || return 1
    scribe_ui_draw_hour_column 1 110 || return 1
    scribe_ui_draw_hour_column 2 315 || return 1
    scribe_ui_draw_hour_column 3 520 || return 1
    scribe_ui_draw_hour_column 4 725 || return 1
    scribe_ui_draw_hour_column 5 930 || return 1
    scribe_ui_draw_hour_column 6 1135 || return 1
    scribe_ui_draw_hour_column 7 1340 || return 1
    scribe_ui_draw_hour_column 8 1545 || return 1
}

scribe_ui_render_dayparts_card() {
    scribe_log "dayparts_render_data=$P1_LABEL:$P1_TEMP:$P1_RAIN:$P1_PRECIP,$P2_LABEL:$P2_TEMP:$P2_RAIN:$P2_PRECIP,$P3_LABEL:$P3_TEMP:$P3_RAIN:$P3_PRECIP,$P4_LABEL:$P4_TEMP:$P4_RAIN:$P4_PRECIP"
    scribe_ui_draw_text dayparts_heading 40 1355 48 110 1640 BOLD LEFT "FROM NOW" || return 1
    scribe_ui_draw_rule 110 1407 1640 3 || return 1
    scribe_ui_draw_daypart_column 1 110 || return 1
    scribe_ui_draw_daypart_column 2 520 || return 1
    scribe_ui_draw_daypart_column 3 930 || return 1
    scribe_ui_draw_daypart_column 4 1340 || return 1
}

scribe_ui_render_daily_card() {
    scribe_ui_draw_text days_heading 40 1835 48 110 1640 BOLD LEFT "NEXT 7 DAYS" || return 1
    scribe_ui_draw_rule 110 1887 1640 3 || return 1
    scribe_ui_draw_day_column 1 110 234 || return 1
    scribe_ui_draw_day_column 2 344 234 || return 1
    scribe_ui_draw_day_column 3 578 234 || return 1
    scribe_ui_draw_day_column 4 812 234 || return 1
    scribe_ui_draw_day_column 5 1046 234 || return 1
    scribe_ui_draw_day_column 6 1280 234 || return 1
    scribe_ui_draw_day_column 7 1514 236 || return 1
}

scribe_ui_render_footer() {
    footer_updated_time="${WEATHER_UPDATED##* }"
    scribe_log "footer_updated_time=$footer_updated_time"
    scribe_ui_draw_rule 110 2338 1640 3 || return 1
    scribe_ui_draw_text updated 30 2355 44 1510 240 REGULAR LEFT "Updated $footer_updated_time" || return 1
}

scribe_ui_render_dashboard() {
    dashboard_location="$1"
    scribe_log "layout_version=scribe-home-009"
    scribe_log "home_daily_section=retained_professional_strip"
    scribe_log "border_asset=./assets/ui/black.png"

    "$SCRIBE_FBINK" -q -b -B WHITE -k >>"$SCRIBE_LOG_FILE" 2>&1
    clear_return_code=$?
    scribe_log "canvas_clear_return_code=$clear_return_code"
    [ "$clear_return_code" -eq 0 ] || return "$clear_return_code"

    scribe_ui_render_header
    header_render_result=$?
    scribe_log "header_render_result=$header_render_result"
    [ "$header_render_result" -eq 0 ] || return "$header_render_result"

    scribe_ui_render_current_card "$dashboard_location"
    current_card_render_result=$?
    scribe_log "current_card_render_result=$current_card_render_result"
    if [ "$current_card_render_result" -ne 0 ]; then
        scribe_log "image_capability=failed"
        return "$current_card_render_result"
    fi
    scribe_log "image_capability=available"

    scribe_ui_render_hourly_card
    hourly_card_render_result=$?
    scribe_log "hourly_card_render_result=$hourly_card_render_result"
    [ "$hourly_card_render_result" -eq 0 ] || return "$hourly_card_render_result"

    scribe_ui_render_dayparts_card
    dayparts_card_render_result=$?
    scribe_log "dayparts_card_render_result=$dayparts_card_render_result"
    [ "$dayparts_card_render_result" -eq 0 ] || return "$dayparts_card_render_result"

    scribe_ui_render_daily_card
    daily_card_render_result=$?
    scribe_log "daily_card_render_result=$daily_card_render_result"
    [ "$daily_card_render_result" -eq 0 ] || return "$daily_card_render_result"

    scribe_ui_render_footer
    footer_render_result=$?
    scribe_log "footer_render_result=$footer_render_result"
    [ "$footer_render_result" -eq 0 ] || return "$footer_render_result"

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
