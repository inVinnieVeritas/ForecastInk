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

scribe_ui_draw_hour_column() {
    hour_index="$1"
    column_left="$2"
    eval "hour_value=\$H${hour_index}_LABEL"
    eval "hour_temp=\$H${hour_index}_TEMP"
    eval "hour_icon=\$H${hour_index}_ICON"
    eval "hour_rain=\$H${hour_index}_RAIN"
    eval "hour_precip=\$H${hour_index}_PRECIP"
    hour_icon_path="$(scribe_ui_icon_path weather "$hour_icon")"

    scribe_ui_draw_text "hour_${hour_index}_time" 36 940 42 "$column_left" 420 BOLD CENTER "$hour_value" || return 1
    scribe_ui_draw_image "hour_${hour_index}_icon" "$hour_icon_path" "$((column_left + 140))" 985 140 140 || return 1
    scribe_ui_draw_text "hour_${hour_index}_temperature" 48 1128 54 "$column_left" 420 BOLD CENTER "${hour_temp}°" || return 1
    scribe_ui_draw_text "hour_${hour_index}_rain" 28 1188 36 "$column_left" 420 REGULAR CENTER "${hour_rain}%   ${hour_precip} mm" || return 1
}

scribe_ui_draw_daypart_column() {
    daypart_index="$1"
    column_left="$2"
    eval "daypart_label=\$P${daypart_index}_LABEL"
    eval "daypart_temp=\$P${daypart_index}_TEMP"
    eval "daypart_icon=\$P${daypart_index}_ICON"
    eval "daypart_rain=\$P${daypart_index}_RAIN"
    eval "daypart_precip=\$P${daypart_index}_PRECIP"
    daypart_icon_path="$(scribe_ui_icon_path weather "$daypart_icon")"

    scribe_ui_draw_text "daypart_${daypart_index}_label" 40 1390 54 "$column_left" 420 BOLD CENTER "$daypart_label" || return 1
    scribe_ui_draw_image "daypart_${daypart_index}_icon" "$daypart_icon_path" "$((column_left + 140))" 1445 140 140 || return 1
    scribe_ui_draw_text "daypart_${daypart_index}_temperature" 48 1588 52 "$column_left" 420 BOLD CENTER "${daypart_temp}°" || return 1
    scribe_ui_draw_text "daypart_${daypart_index}_rain" 28 1642 35 "$column_left" 420 REGULAR CENTER "${daypart_rain}%   ${daypart_precip} mm" || return 1
}

scribe_ui_draw_day_column() {
    day_index="$1"
    column_left="$2"
    eval "day_label=\$D${day_index}_LABEL"
    eval "day_high=\$D${day_index}_HIGH"
    eval "day_low=\$D${day_index}_LOW"
    eval "day_icon=\$D${day_index}_ICON"
    eval "day_amount=\$D${day_index}_MM"
    eval "day_rain=\$D${day_index}_RAIN"
    day_icon_path="$(scribe_ui_icon_path weather "$day_icon")"

    scribe_ui_draw_text "day_${day_index}_label" 38 1838 52 "$column_left" 420 BOLD CENTER "$day_label" || return 1
    scribe_ui_draw_image "day_${day_index}_icon" "$day_icon_path" "$((column_left + 140))" 1890 140 140 || return 1
    scribe_ui_draw_text "day_${day_index}_high" 44 2030 50 "$((column_left + 55))" 145 BOLD CENTER "${day_high}°" || return 1
    scribe_ui_draw_text "day_${day_index}_low" 36 2038 45 "$((column_left + 210))" 155 REGULAR CENTER "/ ${day_low}°" || return 1
    scribe_ui_draw_text "day_${day_index}_amount" 28 2088 32 "$column_left" 420 REGULAR CENTER "${day_amount} mm" || return 1
    scribe_ui_draw_text "day_${day_index}_rain" 30 2125 34 "$column_left" 420 BOLD CENTER "${day_rain}%" || return 1
}

scribe_ui_render_header() {
    header_date="$(date '+%A, %d %B' | sed 's/, 0/, /')"
    header_time="$(date '+%H:%M')"
    scribe_ui_draw_text header_date 44 45 60 90 900 BOLD LEFT "$header_date" || return 1
    scribe_ui_draw_text header_brand 30 55 44 1040 380 REGULAR CENTER "ForecastInk" || return 1
    scribe_ui_draw_text header_time 46 43 62 1510 260 BOLD CENTER "$header_time" || return 1
    scribe_ui_draw_rule 90 140 1680 3 || return 1
}

scribe_ui_render_current_card() {
    current_location="$1"
    hero_icon_path="$(scribe_ui_icon_path hero "$ICON")"
    scribe_log "top_card_layout=refined"
    scribe_ui_draw_box 90 175 1680 610 || return 1
    scribe_ui_draw_text location 64 205 84 140 500 BOLD LEFT "$current_location" || return 1
    scribe_ui_draw_image current_weather "$hero_icon_path" 165 290 390 390 || return 1
    scribe_ui_draw_text current_temperature 158 245 175 820 820 BOLD LEFT "${TEMP}°C" || return 1
    scribe_ui_draw_text current_condition 64 435 75 840 760 BOLD LEFT "$CONDITION" || return 1
    scribe_ui_draw_text feels_like 44 520 58 840 760 REGULAR LEFT "Feels like ${FEELS}°C" || return 1
    scribe_ui_draw_image rain_probability "./assets/ui/rain-probability.png" 840 590 44 44 || return 1
    scribe_ui_draw_text rain_value 40 585 56 905 650 REGULAR LEFT "${CURRENT_RAIN}%   ${CURRENT_PRECIP} mm" || return 1
    scribe_ui_draw_rule 120 690 1620 3 || return 1
    scribe_ui_draw_image sunrise "./assets/ui/sunrise.png" 140 715 54 36 || return 1
    scribe_ui_draw_text sunrise_value 34 708 48 205 370 REGULAR LEFT "Sunrise  $SUNRISE" || return 1
    scribe_ui_draw_image sunset "./assets/ui/sunset.png" 660 715 54 36 || return 1
    scribe_ui_draw_text sunset_value 34 708 48 725 370 REGULAR LEFT "Sunset  $SUNSET" || return 1
    scribe_ui_draw_text high_low 44 706 56 1120 560 BOLD CENTER "High ${HIGH}° / Low ${LOW}°" || return 1
}

scribe_ui_render_hourly_card() {
    scribe_ui_draw_box 90 825 1680 410 || return 1
    scribe_ui_draw_text next_hours_title 46 845 60 130 1500 BOLD LEFT "NEXT FOUR HOURS" || return 1
    scribe_ui_draw_rule 90 920 1680 3 || return 1
    scribe_ui_draw_rule 510 920 3 312 || return 1
    scribe_ui_draw_rule 930 920 3 312 || return 1
    scribe_ui_draw_rule 1350 920 3 312 || return 1
    scribe_ui_draw_hour_column 1 90 || return 1
    scribe_ui_draw_hour_column 2 510 || return 1
    scribe_ui_draw_hour_column 3 930 || return 1
    scribe_ui_draw_hour_column 4 1350 || return 1
}

scribe_ui_render_dayparts_card() {
    scribe_log "dayparts_render_data=$P1_LABEL:$P1_TEMP:$P1_RAIN:$P1_PRECIP,$P2_LABEL:$P2_TEMP:$P2_RAIN:$P2_PRECIP,$P3_LABEL:$P3_TEMP:$P3_RAIN:$P3_PRECIP,$P4_LABEL:$P4_TEMP:$P4_RAIN:$P4_PRECIP"
    scribe_ui_draw_box 90 1275 1680 410 || return 1
    scribe_ui_draw_text next_dayparts_title 46 1295 60 130 1500 BOLD LEFT "NEXT DAYPARTS" || return 1
    scribe_ui_draw_rule 90 1370 1680 3 || return 1
    scribe_ui_draw_rule 510 1370 3 312 || return 1
    scribe_ui_draw_rule 930 1370 3 312 || return 1
    scribe_ui_draw_rule 1350 1370 3 312 || return 1
    scribe_ui_draw_daypart_column 1 90 || return 1
    scribe_ui_draw_daypart_column 2 510 || return 1
    scribe_ui_draw_daypart_column 3 930 || return 1
    scribe_ui_draw_daypart_column 4 1350 || return 1
}

scribe_ui_render_daily_card() {
    scribe_ui_draw_box 90 1725 1680 440 || return 1
    scribe_ui_draw_text next_days_title 46 1745 60 130 1500 BOLD LEFT "NEXT FOUR DAYS" || return 1
    scribe_ui_draw_rule 90 1820 1680 3 || return 1
    scribe_ui_draw_rule 510 1820 3 342 || return 1
    scribe_ui_draw_rule 930 1820 3 342 || return 1
    scribe_ui_draw_rule 1350 1820 3 342 || return 1
    scribe_ui_draw_day_column 1 90 || return 1
    scribe_ui_draw_day_column 2 510 || return 1
    scribe_ui_draw_day_column 3 930 || return 1
    scribe_ui_draw_day_column 4 1350 || return 1
}

scribe_ui_render_footer() {
    scribe_ui_draw_rule 90 2230 1680 3 || return 1
    scribe_ui_draw_text fetch_state 40 2260 54 90 850 BOLD LEFT "$FETCH_STATE" || return 1
    scribe_ui_draw_text updated 36 2260 52 1320 450 REGULAR CENTER "Updated $WEATHER_UPDATED" || return 1
}

scribe_ui_render_dashboard() {
    dashboard_location="$1"
    scribe_log "layout_version=scribe-home-005"
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
