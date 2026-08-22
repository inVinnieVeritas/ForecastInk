#!/bin/sh
BASE="/mnt/us/extensions/KindleDash"; . "$BASE/config.conf"
export LD_LIBRARY_PATH="$BASE/fbink/lib:${LD_LIBRARY_PATH}"
FBINK="$BASE/fbink/bin/fbink"; XH="$BASE/bin/xh"
CACHE="$BASE/cache/weather.json"; TMP="$BASE/cache/weather-latest.json"; LOG="$BASE/cache/kindledash.log"
# Prefer the Kindle's cleaner sans-serif faces for a dashboard UI.
# The exact filenames vary across firmware, so probe safely and fall back to Caecilia.
pick_font(){
  for F in "$@"; do
    [ -f "$F" ] && { echo "$F"; return; }
  done
  echo ""
}

RFONT="$(pick_font   /usr/java/lib/fonts/Helvetica_LT_65_Medium.ttf   /usr/java/lib/fonts/HelveticaNeueLTStd-Roman.ttf   /usr/java/lib/fonts/HelveticaNeueLTStd-Md.ttf   /usr/java/lib/fonts/Futura_LT_65_Medium.ttf   /usr/java/lib/fonts/Caecilia_LT_65_Medium.ttf)"
BFONT="$(pick_font   /usr/java/lib/fonts/Helvetica_LT_75_Bold.ttf   /usr/java/lib/fonts/HelveticaNeueLTStd-Bd.ttf   /usr/java/lib/fonts/HelveticaNeueLTStd-Bold.ttf   /usr/java/lib/fonts/Futura_LT_75_Bold.ttf   /usr/java/lib/fonts/Caecilia_LT_75_Bold.ttf)"

# Futura is excellent for large numeric dashboard information when present.
NRFONT="$(pick_font   /usr/java/lib/fonts/Futura_LT_65_Medium.ttf   /usr/java/lib/fonts/Futura*Medium*.ttf   "$RFONT")"
NBFONT="$(pick_font   /usr/java/lib/fonts/Futura_LT_75_Bold.ttf   /usr/java/lib/fonts/Futura*Bold*.ttf   /usr/java/lib/fonts/Futura*Demi*.ttf   "$BFONT")"

[ -n "$RFONT" ] || RFONT="/usr/java/lib/fonts/Caecilia_LT_65_Medium.ttf"
[ -n "$BFONT" ] || BFONT="/usr/java/lib/fonts/Caecilia_LT_75_Bold.ttf"
[ -n "$NRFONT" ] || NRFONT="$RFONT"
[ -n "$NBFONT" ] || NBFONT="$BFONT"

MODE="$1"
case "$MODE" in
  live|preview-views) ;;
  *) MODE="preview" ;;
esac
VIEW_MODE=0

trap '' HUP TERM
mkdir -p "$BASE/cache"
chmod +x "$XH" "$FBINK" >/dev/null 2>&1

log(){ echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG"; }

condition_text(){ case "$1" in
  0) echo Clear;; 1) echo "Mainly clear";; 2) echo "Partly cloudy";; 3) echo Overcast;;
  45|48) echo Fog;; 51|53|55|56|57) echo Drizzle;; 61|63|65|66|67) echo Rain;;
  71|73|75|77) echo Snow;; 80|81|82) echo "Rain showers";; 85|86) echo "Snow showers";;
  95|96|99) echo Thunderstorm;; *) echo "Weather unavailable";;
esac; }

icon_name(){
  CODE="$1"
  ISDAY="$2"
  case "$CODE" in
    0) [ "$ISDAY" = "0" ] && echo clear-night || echo clear ;;
    1) [ "$ISDAY" = "0" ] && echo clear-night || echo partly ;;
    2) [ "$ISDAY" = "0" ] && echo partly-night || echo partly ;;
    3) echo cloudy ;;
    45|48) echo fog ;;
    51|53|55|56|57|61|63|65|66|67|80|81|82) echo rain ;;
    71|73|75|77|85|86) echo snow ;;
    95|96|99) echo thunder ;;
    *) echo cloudy ;;
  esac
}

hour_label(){
  H="$(echo "$1" | sed 's/.*T\([0-9][0-9]\):.*/\1/')"
  case "$H" in ''|*[!0-9]*) echo "--:--"; return;; esac
  H="${H#0}"; [ -n "$H" ] || H=0
  printf "%02d:00" "$H"
}

clock_time(){
  echo "$1" | sed -n 's/.*T\([0-9][0-9]:[0-9][0-9]\).*/\1/p'
}

big_hour_label(){
  H="$(date '+%I')"
  A="$(date '+%p')"
  H="${H#0}"; [ -n "$H" ] || H=0
  echo "$H $A"
}

nth_line(){ sed -n "${2}p" "$1" 2>/dev/null; }

round_temp(){
  V="$1"
  case "$V" in ''|--|*[!0-9.-]*) echo "$V";; *) awk -v v="$V" 'BEGIN { printf "%.0f", v }';; esac
}

weekday_short(){
  echo "$1" | awk -F- '{
    y=$1+0; m=$2+0; d=$3+0
    if (m < 3) { m += 12; y -= 1 }
    k=y % 100; j=int(y / 100)
    h=(d + int(13 * (m + 1) / 5) + k + int(k / 4) + int(j / 4) + 5 * j) % 7
    split("SAT SUN MON TUE WED THU FRI", names, " ")
    print names[h + 1]
  }'
}

set_forecast_slot(){
  PREFIX="$1"
  LABEL="$2"
  DAY_OFFSET="$3"
  TARGET_HOUR="$4"
  TARGET_HOUR_NUM="${TARGET_HOUR#0}"
  [ -n "$TARGET_HOUR_NUM" ] || TARGET_HOUR_NUM=0
  N=$((DAY_OFFSET * 24 + TARGET_HOUR_NUM + 1))
  V="$(nth_line /tmp/kd_htemps "$N")"
  C="$(nth_line /tmp/kd_hcodes "$N")"
  D="$(nth_line /tmp/kd_hisday "$N")"
  [ -n "$V" ] || V="--"
  [ -n "$C" ] || C=3
  if [ -z "$D" ]; then
    case "$TARGET_HOUR" in 08|8|15|19) D=1 ;; *) D=0 ;; esac
  fi
  eval ${PREFIX}_LABEL=\"$LABEL\"
  eval ${PREFIX}_TEMP=\"$(round_temp "$V")\"
  eval ${PREFIX}_ICON=\"$(icon_name "$C" "$D")\"
}

build_daypart_slots(){
  SLOT_INDEX=1
  DAY_OFFSET=0
  while [ "$SLOT_INDEX" -le 4 ]; do
    for SLOT in "08 MORNING" "15 AFTERNOON" "19 EVENING" "23 TONIGHT"; do
      SLOT_HOUR="${SLOT%% *}"
      SLOT_LABEL="${SLOT#* }"
      SLOT_HOUR_NUM="${SLOT_HOUR#0}"
      if [ "$DAY_OFFSET" -gt 0 ] || [ "$SLOT_HOUR_NUM" -ge "$HNOW" ]; then
        set_forecast_slot "P${SLOT_INDEX}" "$SLOT_LABEL" "$DAY_OFFSET" "$SLOT_HOUR"
        SLOT_INDEX=$((SLOT_INDEX + 1))
        [ "$SLOT_INDEX" -gt 4 ] && break
      fi
    done
    DAY_OFFSET=$((DAY_OFFSET + 1))
  done
}

parse_weather(){
  ONE="$(tr -d '\n' <"$1")"

  TEMP="$(echo "$ONE" | sed -n 's/.*"current":{[^}]*"temperature_2m":\([-0-9.][0-9.]*\).*/\1/p' | head -n1)"
  FEELS="$(echo "$ONE" | sed -n 's/.*"current":{[^}]*"apparent_temperature":\([-0-9.][0-9.]*\).*/\1/p' | head -n1)"
  CODE="$(echo "$ONE" | sed -n 's/.*"current":{[^}]*"weather_code":\([0-9][0-9]*\).*/\1/p' | head -n1)"
  IS_DAY="$(echo "$ONE" | sed -n 's/.*"current":{[^}]*"is_day":\([0-9][0-9]*\).*/\1/p' | head -n1)"

  DOBJ="$(echo "$ONE" | awk 'match($0,/"daily":\{[^}]*\}/){print substr($0,RSTART,RLENGTH)}')"
  HOBJ="$(echo "$ONE" | awk 'match($0,/"hourly":\{[^}]*\}/){print substr($0,RSTART,RLENGTH)}')"

  echo "$DOBJ" | sed -n 's/.*"temperature_2m_max":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >/tmp/kd_dmax
  echo "$DOBJ" | sed -n 's/.*"temperature_2m_min":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >/tmp/kd_dmin
  echo "$DOBJ" | sed -n 's/.*"time":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' | tr -d '"' >/tmp/kd_ddates
  echo "$DOBJ" | sed -n 's/.*"weather_code":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >/tmp/kd_dcodes
  echo "$DOBJ" | sed -n 's/.*"sunrise":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' | tr -d '"' >/tmp/kd_sunrise
  echo "$DOBJ" | sed -n 's/.*"sunset":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' | tr -d '"' >/tmp/kd_sunset

  HIGH="$(nth_line /tmp/kd_dmax 1)"
  LOW="$(nth_line /tmp/kd_dmin 1)"
  SUNRISE="$(clock_time "$(nth_line /tmp/kd_sunrise 1)")"
  SUNSET="$(clock_time "$(nth_line /tmp/kd_sunset 1)")"

  echo "$HOBJ" | sed -n 's/.*"time":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' | tr -d '"' >/tmp/kd_htimes
  echo "$HOBJ" | sed -n 's/.*"temperature_2m":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >/tmp/kd_htemps
  echo "$HOBJ" | sed -n 's/.*"weather_code":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >/tmp/kd_hcodes
  echo "$HOBJ" | sed -n 's/.*"is_day":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >/tmp/kd_hisday
  echo "$HOBJ" | sed -n 's/.*"precipitation_probability":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >/tmp/kd_hrain

  [ -n "$TEMP" ] || TEMP="--"
  [ -n "$FEELS" ] || FEELS="$TEMP"
  [ -n "$HIGH" ] || HIGH="--"
  [ -n "$LOW" ] || LOW="--"
  [ -n "$SUNRISE" ] || SUNRISE="--:--"
  [ -n "$SUNSET" ] || SUNSET="--:--"

  if [ -z "$IS_DAY" ]; then
    CH="$(date '+%H')"
    case "$CH" in 06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21) IS_DAY=1 ;; *) IS_DAY=0 ;; esac
  fi
  CONDITION="$(condition_text "$CODE")"
  ICON="$(icon_name "$CODE" "$IS_DAY")"

  HNOW="$(date '+%H')"
  HNOW="${HNOW#0}"; [ -n "$HNOW" ] || HNOW=0
  BASE_INDEX=$((HNOW + 1))
  CURRENT_RAIN="$(nth_line /tmp/kd_hrain "$BASE_INDEX")"
  case "$CURRENT_RAIN" in ''|null|*[!0-9]*) CURRENT_RAIN=0 ;; esac

  I=1
  while [ $I -le 4 ]; do
    N=$((BASE_INDEX + I))
    T="$(nth_line /tmp/kd_htimes "$N")"
    C="$(nth_line /tmp/kd_hcodes "$N")"
    V="$(nth_line /tmp/kd_htemps "$N")"
    D="$(nth_line /tmp/kd_hisday "$N")"
    R="$(nth_line /tmp/kd_hrain "$N")"
    case "$R" in ''|null|*[!0-9]*) R=0 ;; esac
    if [ -z "$D" ]; then
      HH="${T#*T}"
      HH="${HH%%:*}"
      case "$HH" in 06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21) D=1 ;; *) D=0 ;; esac
    fi
    eval H${I}_LABEL=\"$(hour_label "$T")\"
    eval H${I}_TEMP=\"$(round_temp "$V")\"
    eval H${I}_ICON=\"$(icon_name "$C" "$D")\"
    eval H${I}_RAIN=\"$R\"
    I=$((I + 1))
  done

  build_daypart_slots

  I=1
  while [ $I -le 4 ]; do
    N=$((I + 1))
    DD="$(nth_line /tmp/kd_ddates "$N")"
    DH="$(nth_line /tmp/kd_dmax "$N")"
    DL="$(nth_line /tmp/kd_dmin "$N")"
    DC="$(nth_line /tmp/kd_dcodes "$N")"
    [ -n "$DH" ] || DH="--"
    [ -n "$DL" ] || DL="--"
    [ -n "$DC" ] || DC=3
    if [ -n "$DD" ]; then
      DLABEL="$(weekday_short "$DD")"
    else
      DLABEL="---"
    fi
    eval D${I}_LABEL=\"$DLABEL\"
    eval D${I}_HIGH=\"$(round_temp "$DH")\"
    eval D${I}_LOW=\"$(round_temp "$DL")\"
    eval D${I}_ICON=\"$(icon_name "$DC" 1)\"
    I=$((I + 1))
  done

  TEMP="$(round_temp "$TEMP")"
  FEELS="$(round_temp "$FEELS")"
  HIGH="$(round_temp "$HIGH")"
  LOW="$(round_temp "$LOW")"

  log "parsed temp=$TEMP feels=$FEELS high=$HIGH low=$LOW sunrise=$SUNRISE sunset=$SUNSET hours=$H1_LABEL,$H2_LABEL,$H3_LABEL,$H4_LABEL"
}

fetch_weather(){
  URL="https://api.open-meteo.com/v1/forecast?latitude=${LATITUDE}&longitude=${LONGITUDE}&current=temperature_2m,apparent_temperature,weather_code,is_day&hourly=temperature_2m,weather_code,is_day,precipitation_probability&daily=temperature_2m_max,temperature_2m_min,weather_code,sunrise,sunset&timezone=Europe%2FBrussels&forecast_days=5&models=dwd_icon_seamless"

  rm -f "$TMP"
  log "fetch start"
  "$XH" -d -q -o "$TMP" get "$URL" >>"$LOG" 2>&1
  RC=$?
  BYTES=0
  [ -f "$TMP" ] && BYTES="$(wc -c <"$TMP")"
  log "fetch rc=$RC bytes=$BYTES"

  if [ $RC -eq 0 ] && [ -s "$TMP" ]; then
    cp "$TMP" "$CACHE"
    FETCH_STATE=LIVE
    WEATHER_UPDATED="$(date '+%H:%M')"
    parse_weather "$TMP"
    return 0
  fi
  if [ -s "$CACHE" ]; then
    FETCH_STATE=CACHED
    [ -n "$WEATHER_UPDATED" ] || WEATHER_UPDATED="cached"
    parse_weather "$CACHE"
    return 1
  fi

  FETCH_STATE=OFFLINE
  TEMP="--"; FEELS="--"; HIGH="--"; LOW="--"; CONDITION=Offline; ICON=cloudy
  CURRENT_RAIN=0
  SUNRISE="--:--"; SUNSET="--:--"
  for I in 1 2 3 4; do
    eval H${I}_LABEL=\"--:--\"
    eval H${I}_TEMP=\"--\"
    eval H${I}_ICON=\"cloudy\"
    eval P${I}_LABEL=\"---\"
    eval P${I}_TEMP=\"--\"
    eval H${I}_RAIN=\"0\"
    eval P${I}_ICON=\"cloudy\"
    eval D${I}_LABEL=\"---\"
    eval D${I}_HIGH=\"--\"
    eval D${I}_LOW=\"--\"
    eval D${I}_ICON=\"cloudy\"
  done
  return 1
}

battery(){
  B="$(lipc-get-prop com.lab126.powerd battLevel 2>/dev/null)"
  case "$B" in ''|*[!0-9]*) B="?";; esac
  echo "$B"
}

draw_text(){
  PX="$1"; TOP="$2"; BOTTOM="$3"; LEFT="$4"; RIGHT="$5"; STYLE="$6"; shift 6
  "$FBINK" -q -b -m -t regular="$RFONT",bold="$BFONT",px="$PX",top="$TOP",bottom="$BOTTOM",left="$LEFT",right="$RIGHT",style="$STYLE" "$*" >/dev/null 2>&1
}

draw_cell(){
  PX="$1"; TOP="$2"; BOTTOM="$3"; X="$4"; W="$5"; STYLE="$6"; shift 6
  RIGHT=$((758-X-W))
  draw_text "$PX" "$TOP" "$BOTTOM" "$X" "$RIGHT" "$STYLE" "$*"
}

draw_num(){
  PX="$1"; TOP="$2"; BOTTOM="$3"; LEFT="$4"; RIGHT="$5"; STYLE="$6"; shift 6
  "$FBINK" -q -b -m -t regular="$NRFONT",bold="$NBFONT",px="$PX",top="$TOP",bottom="$BOTTOM",left="$LEFT",right="$RIGHT",style="$STYLE" "$*" >/dev/null 2>&1
}

draw_num_cell(){
  PX="$1"; TOP="$2"; BOTTOM="$3"; X="$4"; W="$5"; STYLE="$6"; shift 6
  RIGHT=$((758-X-W))
  draw_num "$PX" "$TOP" "$BOTTOM" "$X" "$RIGHT" "$STYLE" "$*"
}

draw_line(){
  X="$1"; Y="$2"; W="$3"; H="$4"
  "$FBINK" -q -b -g file="$BASE/assets/ui/black.png",x="$X",y="$Y",w="$W",h="$H" >/dev/null 2>&1
}

draw_box(){
  X="$1"; Y="$2"; W="$3"; H="$4"; T="${5:-2}"
  draw_line "$X" "$Y" "$W" "$T"
  draw_line "$X" $((Y + H - T)) "$W" "$T"
  draw_line "$X" "$Y" "$T" "$H"
  draw_line $((X + W - T)) "$Y" "$T" "$H"
}

draw_digit_clock(){
  T="$(date '+%H:%M')"
  C1="$(echo "$T" | cut -c1)"
  C2="$(echo "$T" | cut -c2)"
  C3="$(echo "$T" | cut -c4)"
  C4="$(echo "$T" | cut -c5)"

  "$FBINK" -q -b -g file="$BASE/assets/digits/${C1}.png",x=105,y=325,w=120,h=210 >/dev/null 2>&1
  "$FBINK" -q -b -g file="$BASE/assets/digits/${C2}.png",x=225,y=325,w=120,h=210 >/dev/null 2>&1
  "$FBINK" -q -b -g file="$BASE/assets/digits/colon.png",x=356,y=325,w=46,h=210 >/dev/null 2>&1
  "$FBINK" -q -b -g file="$BASE/assets/digits/${C3}.png",x=412,y=325,w=120,h=210 >/dev/null 2>&1
  "$FBINK" -q -b -g file="$BASE/assets/digits/${C4}.png",x=532,y=325,w=120,h=210 >/dev/null 2>&1
}


draw_hourly_panel(){
  # NEXT FOUR HOURS PANEL
  X1=18
  X2=196
  X3=374
  X4=552
  COLW=178

  for I in 1 2 3 4; do
    eval X=\$X${I}
    eval LAB=\$H${I}_LABEL
    eval TMPV=\$H${I}_TEMP
    eval ICO=\$H${I}_ICON
    eval RAINV=\$H${I}_RAIN

    draw_num_cell 32 640 350 "$X" "$COLW" BOLD "$LAB"
    "$FBINK" -q -b -g file="$BASE/assets/weather/${ICO}.png",x="$((X + 29))",y=695,w=120,h=120,dither >/dev/null 2>&1
    draw_num_cell 48 824 138 "$X" "$COLW" BOLD "${TMPV}°"
    "$FBINK" -q -b -g file="$BASE/assets/ui/rain-probability.png",x="$((X + 18))",y=904,w=32,h=32,dither >/dev/null 2>&1
    draw_num_cell 36 900 64 "$((X + 8))" "$((COLW - 8))" BOLD "${RAINV}%"
  done
}

draw_dayparts_panel(){
  # NEXT FOUR DAYPARTS PANEL
  X1=18
  X2=196
  X3=374
  X4=552
  COLW=178

  for I in 1 2 3 4; do
    eval X=\$X${I}
    eval LAB=\$P${I}_LABEL
    eval TMPV=\$P${I}_TEMP
    eval ICO=\$P${I}_ICON

    draw_cell 23 640 350 "$X" "$COLW" BOLD "$LAB"
    "$FBINK" -q -b -g file="$BASE/assets/weather/${ICO}.png",x="$((X + 29))",y=695,w=120,h=120,dither >/dev/null 2>&1
    draw_num_cell 48 824 138 "$X" "$COLW" BOLD "${TMPV}°"
  done
}

draw_daily_panel(){
  # NEXT FOUR DAYS PANEL
  X1=18
  X2=196
  X3=374
  X4=552
  COLW=178

  for I in 1 2 3 4; do
    eval X=\$X${I}
    eval LAB=\$D${I}_LABEL
    eval HIGHV=\$D${I}_HIGH
    eval LOWV=\$D${I}_LOW
    eval ICO=\$D${I}_ICON

    draw_cell 32 640 350 "$X" "$COLW" BOLD "$LAB"
    "$FBINK" -q -b -g file="$BASE/assets/weather/${ICO}.png",x="$((X + 29))",y=695,w=120,h=120,dither >/dev/null 2>&1
    draw_num_cell 34 824 138 "$X" "$COLW" BOLD "${HIGHV}°/${LOWV}°"
  done
}
draw_dashboard(){
  TODAY="$(date '+%A, %d %B')"
  BATT="$(battery)"
  NOW_SLOT="$(date '+%H:00')"
  [ -n "$WEATHER_UPDATED" ] || WEATHER_UPDATED="--:--"

  BATT_ICON="battery-unknown"
  case "$BATT" in
    ''|'?') BATT_ICON="battery-unknown" ;;
    *)
      if [ "$BATT" -ge 88 ] 2>/dev/null; then
        BATT_ICON="battery-100"
      elif [ "$BATT" -ge 63 ] 2>/dev/null; then
        BATT_ICON="battery-75"
      elif [ "$BATT" -ge 38 ] 2>/dev/null; then
        BATT_ICON="battery-50"
      elif [ "$BATT" -ge 13 ] 2>/dev/null; then
        BATT_ICON="battery-25"
      else
        BATT_ICON="battery-0"
      fi
      ;;
  esac

  "$FBINK" -q -b -k >/dev/null 2>&1
  "$FBINK" -q -b -g file="$BASE/assets/ui/station-bg.png",x=0,y=0,w=758,h=1024 >/dev/null 2>&1

  # HEADER
  draw_text 40 8 957 10 290 BOLD "$TODAY"
  "$FBINK" -q -b -g file="$BASE/assets/ui/${BATT_ICON}.png",x=548,y=17,w=62,h=33 >/dev/null 2>&1
  draw_num 31 17 973 610 22 BOLD "${BATT}%"

  # CURRENT CONDITIONS PANEL
  draw_text 46 126 820 34 420 BOLD "$LOCATION"
  draw_num 66 124 820 360 28 BOLD "$NOW_SLOT"

  "$FBINK" -q -b -g file="$BASE/assets/hero/${ICON}.png",x=36,y=190,w=284,h=284,dither >/dev/null 2>&1

  draw_num 139 198 666 360 28 BOLD "${TEMP}°C"
  draw_text 61 350 470 360 28 BOLD "$CONDITION"
  if [ "$CURRENT_RAIN" -ge 15 ] 2>/dev/null; then
    draw_text 44 420 405 360 165 BOLD "Feels ${FEELS}°C"
    "$FBINK" -q -b -g file="$BASE/assets/ui/rain-probability.png",x=598,y=432,w=28,h=28,dither >/dev/null 2>&1
    draw_text 44 420 405 628 28 BOLD "${CURRENT_RAIN}%"
  else
    draw_text 54 420 405 360 28 BOLD "Feels ${FEELS}°C"
  fi
  draw_text 40 515 344 360 28 BOLD "High ${HIGH}°C / Low ${LOW}°C"

  "$FBINK" -q -b -g file="$BASE/assets/ui/sunrise.png",x=54,y=500,w=48,h=32,dither >/dev/null 2>&1
  draw_text 32 500 486 64 384 BOLD "SUNRISE  ${SUNRISE}"
  "$FBINK" -q -b -g file="$BASE/assets/ui/sunset.png",x=54,y=540,w=48,h=32,dither >/dev/null 2>&1
  draw_text 32 540 446 64 384 BOLD "SUNSET   ${SUNSET}"

  case "$VIEW_MODE" in
    1) draw_dayparts_panel ;;
    2) draw_daily_panel ;;
    *) draw_hourly_panel ;;
  esac


  # Footer: one compact line, pushed lower to give precipitation probability more room.
  draw_text 28 952 14 170 170 BOLD "LAST REFRESHED  ${WEATHER_UPDATED}"

  "$FBINK" -q -f -s -W GC16 -w >/dev/null 2>&1
}

rtc_path(){
  for R in /sys/class/rtc/rtc1/wakealarm /sys/class/rtc/rtc0/wakealarm; do
    [ -e "$R" ] && echo "$R" && return
  done
}

suspend_for(){
  S="$1"; R="$(rtc_path)"
  if [ -n "$R" ]; then
    echo 0 >"$R" 2>/dev/null || true
    echo "+$S" >"$R" 2>/dev/null || true
  fi
  sync
  echo mem >/sys/power/state
}

seconds_until_next_hour(){
  M="$(date '+%M')"
  S="$(date '+%S')"
  M="${M#0}"; [ -n "$M" ] || M=0
  S="${S#0}"; [ -n "$S" ] || S=0
  echo $((3600 - (M * 60 + S)))
}

: >"$LOG"
log "beta.45 start mode=$MODE"
log "fonts regular=$RFONT bold=$BFONT numeric_regular=$NRFONT numeric_bold=$NBFONT"
fetch_weather

lipc-set-prop com.lab126.powerd preventScreenSaver 1 >/dev/null 2>&1
/sbin/stop framework >/dev/null 2>&1 || true
/sbin/stop lab126_gui >/dev/null 2>&1 || true
sleep 2

if [ "$MODE" = "preview-views" ]; then
  for VIEW_MODE in 0 1 2; do
    log "preview forecast view mode=$VIEW_MODE"
    draw_dashboard
    sleep 20
  done
  /sbin/reboot
  exit 0
fi
draw_dashboard

if [ "$MODE" = "preview" ]; then
  suspend_for "$PREVIEW_SECONDS"
  sleep 3
  /sbin/reboot
  exit 0
fi

while true; do
  WAIT_SECS="$(seconds_until_next_hour)"
  log "next aligned refresh in ${WAIT_SECS}s"
  suspend_for "$WAIT_SECS"
  # Give Wi-Fi a few seconds after RTC wake, then fetch current data.
  sleep 12
  if fetch_weather; then
    VIEW_MODE=$(((VIEW_MODE + 1) % 3))
    log "forecast view advanced to mode=$VIEW_MODE"
  fi
  draw_dashboard
done
