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

    scribe_ui_draw_text "hour_${hour_index}_time" 48 1170 60 "$column_left" 420 BOLD CENTER "$hour_value" || return 1
    scribe_ui_draw_image "hour_${hour_index}_icon" "$hour_icon_path" "$((column_left + 105))" 1235 210 210 || return 1
    scribe_ui_draw_text "hour_${hour_index}_temperature" 70 1445 78 "$column_left" 420 BOLD CENTER "${hour_temp}°" || return 1
    scribe_ui_draw_image "hour_${hour_index}_rain_icon" "./assets/ui/rain-probability.png" "$((column_left + 35))" 1532 40 40 || return 1
    scribe_ui_draw_text "hour_${hour_index}_rain" 42 1526 50 "$((column_left + 85))" 120 BOLD LEFT "${hour_rain}%" || return 1
    scribe_ui_draw_text "hour_${hour_index}_precip" 36 1530 46 "$((column_left + 220))" 180 REGULAR LEFT "${hour_precip} mm" || return 1
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

    scribe_ui_draw_text "daypart_${daypart_index}_label" 54 1750 66 "$column_left" 420 BOLD CENTER "$daypart_label" || return 1
    scribe_ui_draw_image "daypart_${daypart_index}_icon" "$daypart_icon_path" "$((column_left + 105))" 1820 210 210 || return 1
    scribe_ui_draw_text "daypart_${daypart_index}_temperature" 70 2030 78 "$column_left" 420 BOLD CENTER "${daypart_temp}°" || return 1
    scribe_ui_draw_image "daypart_${daypart_index}_rain_icon" "./assets/ui/rain-probability.png" "$((column_left + 35))" 2113 40 40 || return 1
    scribe_ui_draw_text "daypart_${daypart_index}_rain" 42 2108 50 "$((column_left + 85))" 120 BOLD LEFT "${daypart_rain}%" || return 1
    scribe_ui_draw_text "daypart_${daypart_index}_precip" 36 2112 46 "$((column_left + 220))" 180 REGULAR LEFT "${daypart_precip} mm" || return 1
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
    scribe_log "top_card_layout=professional-007"
    scribe_ui_draw_box 90 175 1680 825 || return 1
    scribe_ui_draw_text location 82 210 105 140 560 BOLD LEFT "$current_location" || return 1
    scribe_ui_draw_image current_weather "$hero_icon_path" 140 345 520 520 || return 1
    scribe_ui_draw_text current_temperature 230 245 260 780 900 BOLD LEFT "${TEMP}°C" || return 1
    scribe_ui_draw_text current_condition 88 510 105 810 820 BOLD LEFT "$CONDITION" || return 1
    scribe_ui_draw_text feels_like 56 625 72 810 820 REGULAR LEFT "Feels like ${FEELS}°C" || return 1
    scribe_ui_draw_image rain_probability "./assets/ui/rain-probability.png" 810 735 80 80 || return 1
    scribe_ui_draw_text rain_value 72 720 95 910 220 BOLD LEFT "${CURRENT_RAIN}%" || return 1
    scribe_ui_draw_text precip_value 46 742 62 1165 400 REGULAR LEFT "${CURRENT_PRECIP} mm" || return 1
    scribe_ui_draw_rule 120 880 1620 3 || return 1
    scribe_ui_draw_image sunrise "./assets/ui/sunrise.png" 140 915 80 54 || return 1
    scribe_ui_draw_text sunrise_value 48 908 64 240 360 REGULAR LEFT "Sunrise  $SUNRISE" || return 1
    scribe_ui_draw_image sunset "./assets/ui/sunset.png" 650 915 80 54 || return 1
    scribe_ui_draw_text sunset_value 48 908 64 750 360 REGULAR LEFT "Sunset  $SUNSET" || return 1
    scribe_ui_draw_text high_low 60 902 78 1150 560 BOLD CENTER "High ${HIGH}° / Low ${LOW}°" || return 1
}

scribe_ui_render_hourly_card() {
    scribe_ui_draw_box 90 1040 1680 540 || return 1
    scribe_ui_draw_text next_hours_title 52 1065 70 130 1500 BOLD LEFT "NEXT FOUR HOURS" || return 1
    scribe_ui_draw_rule 90 1145 1680 3 || return 1
    scribe_ui_draw_rule 510 1145 3 432 || return 1
    scribe_ui_draw_rule 930 1145 3 432 || return 1
    scribe_ui_draw_rule 1350 1145 3 432 || return 1
    scribe_ui_draw_hour_column 1 90 || return 1
    scribe_ui_draw_hour_column 2 510 || return 1
    scribe_ui_draw_hour_column 3 930 || return 1
    scribe_ui_draw_hour_column 4 1350 || return 1
}

scribe_ui_render_dayparts_card() {
    scribe_log "dayparts_render_data=$P1_LABEL:$P1_TEMP:$P1_RAIN:$P1_PRECIP,$P2_LABEL:$P2_TEMP:$P2_RAIN:$P2_PRECIP,$P3_LABEL:$P3_TEMP:$P3_RAIN:$P3_PRECIP,$P4_LABEL:$P4_TEMP:$P4_RAIN:$P4_PRECIP"
    scribe_ui_draw_box 90 1620 1680 540 || return 1
    scribe_ui_draw_text next_dayparts_title 52 1645 70 130 1500 BOLD LEFT "NEXT DAYPARTS" || return 1
    scribe_ui_draw_rule 90 1725 1680 3 || return 1
    scribe_ui_draw_rule 510 1725 3 432 || return 1
    scribe_ui_draw_rule 930 1725 3 432 || return 1
    scribe_ui_draw_rule 1350 1725 3 432 || return 1
    scribe_ui_draw_daypart_column 1 90 || return 1
    scribe_ui_draw_daypart_column 2 510 || return 1
    scribe_ui_draw_daypart_column 3 930 || return 1
    scribe_ui_draw_daypart_column 4 1350 || return 1
}

scribe_ui_render_footer() {
    scribe_ui_draw_rule 90 2230 1680 3 || return 1
    scribe_ui_draw_text fetch_state 40 2260 54 90 850 BOLD LEFT "$FETCH_STATE" || return 1
    scribe_ui_draw_text updated 36 2260 52 1320 450 REGULAR CENTER "Updated $WEATHER_UPDATED" || return 1
}

scribe_ui_render_dashboard() {
    dashboard_location="$1"
    scribe_log "layout_version=scribe-home-007"
    scribe_log "home_daily_section=omitted_for_readability"
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
