#!/bin/sh
if [ "${PAPERCAST_RUNTIME_COPY:-0}" != "1" ]; then
  PAPERCAST_RUNTIME_COPY_PATH="/tmp/papercast-run.$$"
  cp -p "$0" "$PAPERCAST_RUNTIME_COPY_PATH" 2>/dev/null || exit 1
  chmod 700 "$PAPERCAST_RUNTIME_COPY_PATH" 2>/dev/null || exit 1
  PAPERCAST_RUNTIME_COPY=1
  export PAPERCAST_RUNTIME_COPY PAPERCAST_RUNTIME_COPY_PATH
  exec /bin/sh "$PAPERCAST_RUNTIME_COPY_PATH" "$@"
fi

BASE="/mnt/us/extensions/KindleDash"; . "$BASE/config.conf"
export LD_LIBRARY_PATH="$BASE/fbink/lib:${LD_LIBRARY_PATH}"
FBINK="$BASE/fbink/bin/fbink"; XH="$BASE/bin/xh"
CACHE="$BASE/cache/weather.json"; TMP="$BASE/cache/weather-latest.json"; LOG="$BASE/cache/kindledash.log"
WEATHER_CACHE_LOCATION="$BASE/cache/weather.location"
. "$BASE/bin/location.sh"
. "$BASE/bin/wake.sh"
RESUME_LOG="/tmp/papercast-resume.log"
WAKE_TOLERANCE_SECONDS=90
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
  live|live-hourly|preview|preview-hourly|preview-dayparts|preview-daily|preview-views) ;;
  *) MODE="preview" ;;
esac
VIEW_MODE=0

trap '' HUP TERM
mkdir -p "$BASE/cache"
chmod +x "$XH" "$FBINK" >/dev/null 2>&1

log(){ echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG"; }

resume_log(){
  RESUME_MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') $*"
  printf '%s\n' "$RESUME_MESSAGE" >>"$RESUME_LOG" 2>/dev/null || true
  if [ "${PAPERCAST_STORAGE_AVAILABLE:-1}" = "1" ]; then
    printf '%s\n' "$RESUME_MESSAGE" >>"$LOG" 2>/dev/null || true
  fi
}

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

format_precip(){
  awk -v v="$1" 'BEGIN {
    if (v !~ /^[0-9]+([.][0-9]+)?$/) v=0
    printf "%.1f", v + 0
  }'
}

format_percent(){
  awk -v v="$1" 'BEGIN {
    if (v !~ /^[0-9]+([.][0-9]+)?$/) v=0
    printf "%.0f", v + 0
  }'
}

daypart_precip_total(){
  LABEL="$1"
  DAY_OFFSET="$2"
  case "$LABEL" in
    MORNING)
      START_ABS=$((DAY_OFFSET * 24 + 7)); END_ABS=$((DAY_OFFSET * 24 + 12)) ;;
    AFTERNOON)
      START_ABS=$((DAY_OFFSET * 24 + 13)); END_ABS=$((DAY_OFFSET * 24 + 18)) ;;
    EVENING)
      START_ABS=$((DAY_OFFSET * 24 + 19)); END_ABS=$((DAY_OFFSET * 24 + 22)) ;;
    TONIGHT)
      START_ABS=$((DAY_OFFSET * 24 + 23)); END_ABS=$(((DAY_OFFSET + 1) * 24 + 6)) ;;
    *)
      echo "0.0"
      return ;;
  esac

  TOTAL=0
  A="$START_ABS"
  while [ "$A" -le "$END_ABS" ]; do
    V="$(nth_line /tmp/kd_hprecip "$((A + 1))")"
    TOTAL="$(awk -v total="$TOTAL" -v value="$V" 'BEGIN {
      if (value !~ /^[0-9]+([.][0-9]+)?$/) value=0
      printf "%.4f", total + value
    }')"
    A=$((A + 1))
  done
  format_precip "$TOTAL"
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
  R="$(nth_line /tmp/kd_hrain "$N")"
  [ -n "$V" ] || V="--"
  [ -n "$C" ] || C=3
  case "$R" in \'\'|null|*[!0-9]*) R=0 ;; esac
  if [ -z "$D" ]; then
    case "$TARGET_HOUR" in 08|8|15|19) D=1 ;; *) D=0 ;; esac
  fi
  eval ${PREFIX}_LABEL=\"$LABEL\"
  eval ${PREFIX}_TEMP=\"$(round_temp "$V")\"
  eval ${PREFIX}_ICON=\"$(icon_name "$C" "$D")\"
  eval ${PREFIX}_RAIN="$R"
  eval ${PREFIX}_PRECIP=\"$(daypart_precip_total "$LABEL" "$DAY_OFFSET")\"
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
  echo "$DOBJ" | sed -n 's/.*"precipitation_sum":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >/tmp/kd_dprecip
  echo "$DOBJ" | sed -n 's/.*"precipitation_probability_max":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >/tmp/kd_drain

  HIGH="$(nth_line /tmp/kd_dmax 1)"
  LOW="$(nth_line /tmp/kd_dmin 1)"
  SUNRISE="$(clock_time "$(nth_line /tmp/kd_sunrise 1)")"
  SUNSET="$(clock_time "$(nth_line /tmp/kd_sunset 1)")"

  echo "$HOBJ" | sed -n 's/.*"time":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' | tr -d '"' >/tmp/kd_htimes
  echo "$HOBJ" | sed -n 's/.*"temperature_2m":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >/tmp/kd_htemps
  echo "$HOBJ" | sed -n 's/.*"weather_code":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >/tmp/kd_hcodes
  echo "$HOBJ" | sed -n 's/.*"is_day":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >/tmp/kd_hisday
  echo "$HOBJ" | sed -n 's/.*"precipitation_probability":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >/tmp/kd_hrain
  echo "$HOBJ" | sed -n 's/.*"precipitation":\[\([^]]*\)\].*/\1/p' | tr ',' '\n' >/tmp/kd_hprecip

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
  CURRENT_PRECIP="$(nth_line /tmp/kd_hprecip "$BASE_INDEX")"
  CURRENT_PRECIP="$(format_precip "$CURRENT_PRECIP")"

  I=1
  while [ $I -le 4 ]; do
    N=$((BASE_INDEX + I))
    T="$(nth_line /tmp/kd_htimes "$N")"
    C="$(nth_line /tmp/kd_hcodes "$N")"
    V="$(nth_line /tmp/kd_htemps "$N")"
    D="$(nth_line /tmp/kd_hisday "$N")"
    R="$(nth_line /tmp/kd_hrain "$N")"
    A="$(nth_line /tmp/kd_hprecip "$N")"
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
    eval H${I}_PRECIP=\"$(format_precip "$A")\"
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
    DA="$(nth_line /tmp/kd_dprecip "$N")"
    DR="$(nth_line /tmp/kd_drain "$N")"
    [ -n "$DH" ] || DH="--"
    [ -n "$DL" ] || DL="--"
    [ -n "$DC" ] || DC=3
    DR="$(format_percent "$DR")"
    if [ -n "$DD" ]; then
      DLABEL="$(weekday_short "$DD")"
    else
      DLABEL="---"
    fi
    eval D${I}_LABEL=\"$DLABEL\"
    eval D${I}_HIGH=\"$(round_temp "$DH")\"
    eval D${I}_LOW=\"$(round_temp "$DL")\"
    eval D${I}_ICON=\"$(icon_name "$DC" 1)\"
    eval D${I}_MM=\"$(format_precip "$DA")\"
    eval D${I}_RAIN=\"$DR\"
    I=$((I + 1))
  done

  TEMP="$(round_temp "$TEMP")"
  FEELS="$(round_temp "$FEELS")"
  HIGH="$(round_temp "$HIGH")"
  LOW="$(round_temp "$LOW")"

  log "parsed temp=$TEMP feels=$FEELS high=$HIGH low=$LOW sunrise=$SUNRISE sunset=$SUNSET hours=$H1_LABEL,$H2_LABEL,$H3_LABEL,$H4_LABEL"
}

weather_location_key(){
  printf '%s|%s|%s' "$LATITUDE" "$LONGITUDE" "$TIMEZONE"
}

weather_cache_matches(){
  [ -s "$CACHE" ] || return 1
  if [ -f "$WEATHER_CACHE_LOCATION" ]; then
    IFS= read -r CACHED_WEATHER_LOCATION <"$WEATHER_CACHE_LOCATION" || return 1
    [ "$CACHED_WEATHER_LOCATION" = "$(weather_location_key)" ]
    return
  fi
  # Backward compatibility for an existing pre-location-feature cache when
  # the user still has a complete explicit override.
  [ "$LOCATION_SOURCE" = "explicit" ]
}

save_weather_cache(){
  CACHE_KEY_NEW="${WEATHER_CACHE_LOCATION}.new"
  cp "$TMP" "$CACHE" 2>/dev/null || return 1
  weather_location_key >"$CACHE_KEY_NEW" 2>/dev/null || return 1
  mv "$CACHE_KEY_NEW" "$WEATHER_CACHE_LOCATION" 2>/dev/null || return 1
  return 0
}

set_offline_weather(){
  FETCH_STATE=OFFLINE
  TEMP="--"; FEELS="--"; HIGH="--"; LOW="--"; CONDITION=Offline; ICON=cloudy
  CURRENT_RAIN=0
  CURRENT_PRECIP="0.0"
  SUNRISE="--:--"; SUNSET="--:--"
  for I in 1 2 3 4; do
    eval H${I}_LABEL=\"--:--\"
    eval H${I}_TEMP=\"--\"
    eval H${I}_ICON=\"cloudy\"
    eval P${I}_LABEL=\"---\"
    eval P${I}_TEMP=\"--\"
    eval H${I}_RAIN=\"0\"
    eval H${I}_PRECIP=\"0.0\"
    eval P${I}_RAIN="0"
    eval P${I}_PRECIP=\"0.0\"
    eval P${I}_ICON=\"cloudy\"
    eval D${I}_LABEL=\"---\"
    eval D${I}_HIGH=\"--\"
    eval D${I}_LOW=\"--\"
    eval D${I}_ICON=\"cloudy\"
    eval D${I}_MM=\"0.0\"
    eval D${I}_RAIN=\"0\"
  done
}
fetch_weather(){
  if ! resolve_location; then
    log "weather fetch skipped: location unresolved for '$LOCATION'"
    set_offline_weather
    return 1
  fi

  TIMEZONE_URL="$(printf '%s' "$TIMEZONE" | sed 's/+/%2B/g; s|/|%2F|g')"
  URL="https://api.open-meteo.com/v1/forecast?latitude=${LATITUDE}&longitude=${LONGITUDE}&current=temperature_2m,apparent_temperature,weather_code,is_day&hourly=temperature_2m,weather_code,is_day,precipitation_probability,precipitation&daily=temperature_2m_max,temperature_2m_min,weather_code,precipitation_sum,precipitation_probability_max,sunrise,sunset&timezone=${TIMEZONE_URL}&precipitation_unit=mm&forecast_days=5&models=dwd_icon_seamless"

  rm -f "$TMP"
  log "fetch start"
  "$XH" -d -q -o "$TMP" get "$URL" >>"$LOG" 2>&1
  RC=$?
  BYTES=0
  [ -f "$TMP" ] && BYTES="$(wc -c <"$TMP")"
  log "fetch rc=$RC bytes=$BYTES"

  if [ $RC -eq 0 ] && [ -s "$TMP" ]; then
    if ! save_weather_cache; then
      log "weather cache write failed"
    fi
    FETCH_STATE=LIVE
    WEATHER_UPDATED="$(date '+%H:%M')"
    parse_weather "$TMP"
    return 0
  fi
  if weather_cache_matches; then
    FETCH_STATE=CACHED
    [ -n "$WEATHER_UPDATED" ] || WEATHER_UPDATED="cached"
    parse_weather "$CACHE"
    return 1
  fi
  [ -s "$CACHE" ] && log "weather cache ignored: location does not match current coordinates/timezone"
  set_offline_weather
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


forecast_icon_y_offset(){
  case "$1" in
    partly) echo 7 ;;
    partly-night) echo 5 ;;
    rain) echo -3 ;;
    snow) echo -4 ;;
    fog|thunder) echo -6 ;;
    *) echo 0 ;;
  esac
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
    eval PRECIPV=\$H${I}_PRECIP
    ICON_Y=$((691 + $(forecast_icon_y_offset "$ICO")))

    draw_num_cell 32 640 350 "$X" "$COLW" BOLD "$LAB"
    "$FBINK" -q -b -g file="$BASE/assets/weather/${ICO}.png",x="$((X + 29))",y="$ICON_Y",w=120,h=120,dither >/dev/null 2>&1
    draw_num_cell 50 794 168 "$X" "$COLW" BOLD "${TMPV}°"
    draw_cell 36 836 150 "$X" "$COLW" BOLD "${PRECIPV} mm"
    "$FBINK" -q -b -g file="$BASE/assets/ui/rain-probability.png",x="$((X + 18))",y=902,w=32,h=32,dither >/dev/null 2>&1
    draw_num_cell 36 898 76 "$((X + 8))" "$((COLW - 8))" BOLD "${RAINV}%"
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
    eval RAINV=\$P${I}_RAIN
    eval PRECIPV=\$P${I}_PRECIP
    ICON_Y=$((691 + $(forecast_icon_y_offset "$ICO")))

    draw_cell 23 640 350 "$X" "$COLW" BOLD "$LAB"
    "$FBINK" -q -b -g file="$BASE/assets/weather/${ICO}.png",x="$((X + 29))",y="$ICON_Y",w=120,h=120,dither >/dev/null 2>&1
    draw_num_cell 50 794 168 "$X" "$COLW" BOLD "${TMPV}°"
    draw_cell 36 836 150 "$X" "$COLW" BOLD "${PRECIPV} mm"
    "$FBINK" -q -b -g file="$BASE/assets/ui/rain-probability.png",x="$((X + 18))",y=902,w=32,h=32,dither >/dev/null 2>&1
    draw_num_cell 36 898 76 "$((X + 8))" "$((COLW - 8))" BOLD "${RAINV}%"
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
    ICON_Y=$((711 + $(forecast_icon_y_offset "$ICO")))

    draw_cell 32 640 350 "$X" "$COLW" BOLD "$LAB"
    "$FBINK" -q -b -g file="$BASE/assets/weather/${ICO}.png",x="$((X + 29))",y="$ICON_Y",w=120,h=120,dither >/dev/null 2>&1
    eval MMV=\$D${I}_MM
    eval RAINV=\$D${I}_RAIN
    draw_num_cell 34 806 156 "$X" "$COLW" BOLD "${HIGHV}°/${LOWV}°"
    draw_cell 36 868 118 "$X" "$COLW" BOLD "${MMV} mm"
    "$FBINK" -q -b -g file="$BASE/assets/ui/rain-probability.png",x="$((X + 18))",y=912,w=32,h=32,dither >/dev/null 2>&1
    draw_num_cell 36 908 78 "$((X + 8))" "$((COLW - 8))" BOLD "${RAINV}%"
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

  STATION_BG="station-bg.png"
  [ "$VIEW_MODE" = "2" ] && STATION_BG="station-bg-daily.png"
  "$FBINK" -q -b -k >/dev/null 2>&1
  "$FBINK" -q -b -g file="$BASE/assets/ui/${STATION_BG}",x=0,y=0,w=758,h=1024 >/dev/null 2>&1

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
  draw_text 44 420 405 360 165 BOLD "Feels ${FEELS}°C"
  "$FBINK" -q -b -g file="$BASE/assets/ui/rain-probability.png",x=598,y=432,w=28,h=28,dither >/dev/null 2>&1
  draw_text 44 420 405 628 28 BOLD "${CURRENT_RAIN}%"
  draw_text 26 470 526 598 28 BOLD "${CURRENT_PRECIP} mm"
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
  draw_text 28 976 14 170 170 BOLD "LAST REFRESHED  ${WEATHER_UPDATED}"

  "$FBINK" -q -f -s -W GC16 -w >/dev/null 2>&1
}

rtc_path(){
  for R in /sys/class/rtc/rtc1/wakealarm /sys/class/rtc/rtc0/wakealarm; do
    [ -e "$R" ] && echo "$R" && return
  done
}

usb_storage_active(){
  USB_POWER_STATE=""
  if [ -x /usr/bin/lipc-get-prop ]; then
    USB_POWER_STATE="$(/usr/bin/lipc-get-prop -i com.lab126.powerd isCharging 2>/dev/null)"
  fi
  case "$USB_POWER_STATE" in
    1|true|yes) return 0 ;;
  esac

  for USB_LUN_PATH in \
    /sys/devices/platform/fsl-usb2-udc/gadget/lun0/file \
    /sys/class/android_usb/android0/f_mass_storage/lun0/file \
    /sys/devices/virtual/android_usb/android0/f_mass_storage/lun0/file; do
    [ -r "$USB_LUN_PATH" ] || continue
    IFS= read -r USB_LUN_VALUE <"$USB_LUN_PATH" || USB_LUN_VALUE=""
    [ -n "$USB_LUN_VALUE" ] && return 0
  done
  return 1
}

cancel_rtc_wake(){
  RTC_CANCEL_RC=0
  if [ -n "${RTC_WAKEALARM:-}" ] && [ -e "$RTC_WAKEALARM" ]; then
    echo 0 >"$RTC_WAKEALARM" 2>/dev/null || RTC_CANCEL_RC=$?
    return "$RTC_CANCEL_RC"
  fi
  for RTC_CANCEL_PATH in /sys/class/rtc/rtc1/wakealarm /sys/class/rtc/rtc0/wakealarm; do
    [ -e "$RTC_CANCEL_PATH" ] || continue
    echo 0 >"$RTC_CANCEL_PATH" 2>/dev/null || RTC_CANCEL_RC=$?
  done
  return "$RTC_CANCEL_RC"
}

CLEAN_EXIT_STATE="idle"
clean_exit(){
  [ "$CLEAN_EXIT_STATE" = "idle" ] || return 0
  CLEAN_EXIT_STATE="running"
  resume_log "clean exit starting"

  if [ -x /usr/bin/lipc-set-prop ]; then
    /usr/bin/lipc-set-prop com.lab126.powerd preventScreenSaver 1 >/dev/null 2>&1 || true
  fi
  cancel_rtc_wake

  if [ -x /sbin/start ]; then
    (cd / && /sbin/start lab126_gui) >/dev/null 2>&1 || true
  elif [ -x /etc/init.d/framework ]; then
    (cd / && /etc/init.d/framework start) >/dev/null 2>&1 || true
  fi

  sleep 2
  if [ -x /usr/bin/lipc-set-prop ]; then
    /usr/bin/lipc-set-prop com.lab126.pillow disableEnablePillow enable >/dev/null 2>&1 || true
    if [ "${USB_STORAGE_ACTIVE:-0}" != "1" ] && usb_storage_active; then
      USB_STORAGE_ACTIVE=1
      PAPERCAST_STORAGE_AVAILABLE=0
    fi
    if [ "${USB_STORAGE_ACTIVE:-0}" != "1" ]; then
      /usr/bin/lipc-set-prop com.lab126.appmgrd start app://com.lab126.booklet.home >/dev/null 2>&1 || true
      sleep 1
      /usr/bin/lipc-set-prop com.lab126.appmgrd start app://com.lab126.booklet.home >/dev/null 2>&1 || true
    else
      resume_log "USB storage active; Home request skipped"
    fi
  fi

  [ -n "${PAPERCAST_RUNTIME_COPY_PATH:-}" ] && rm -f "$PAPERCAST_RUNTIME_COPY_PATH"
  CLEAN_EXIT_STATE="done"
  resume_log "clean exit complete"
  if [ -x /usr/bin/lipc-set-prop ]; then
    /usr/bin/lipc-set-prop com.lab126.powerd preventScreenSaver 0 >/dev/null 2>&1 || true
  fi
}

suspend_for(){
  S="$1"
  SCHEDULE_EPOCH="$(date '+%s')"
  EXPECTED_WAKE_EPOCH=$((SCHEDULE_EPOCH + S))
  RTC_WAKEALARM="$(rtc_path)"
  if [ -n "$RTC_WAKEALARM" ]; then
    echo 0 >"$RTC_WAKEALARM" 2>/dev/null || true
    echo "+$S" >"$RTC_WAKEALARM" 2>/dev/null || true
  fi
  resume_log "scheduled wake epoch=$EXPECTED_WAKE_EPOCH"
  sync
  echo mem >/sys/power/state

  RESUME_EPOCH="$(date '+%s')"
  RESUME_DELTA="$(resume_delta "$EXPECTED_WAKE_EPOCH" "$RESUME_EPOCH")"
  RESUME_REASON="$(classify_resume "$EXPECTED_WAKE_EPOCH" "$RESUME_EPOCH" "$WAKE_TOLERANCE_SECONDS")"
  USB_STORAGE_ACTIVE=0
  PAPERCAST_STORAGE_AVAILABLE=1
  if [ "$RESUME_REASON" = "external-early" ] && usb_storage_active; then
    USB_STORAGE_ACTIVE=1
    PAPERCAST_STORAGE_AVAILABLE=0
  fi
  resume_log "resume epoch=$RESUME_EPOCH"
  resume_log "resume delta=$RESUME_DELTA"
  resume_log "resume reason=$RESUME_REASON"
}

seconds_until_next_hour(){
  M="$(date '+%M')"
  S="$(date '+%S')"
  M="${M#0}"; [ -n "$M" ] || M=0
  S="${S#0}"; [ -n "$S" ] || S=0
  echo $((3600 - (M * 60 + S)))
}

: >"$LOG"
: >"$RESUME_LOG"
log "beta.45 start mode=$MODE"
log "fonts regular=$RFONT bold=$BFONT numeric_regular=$NRFONT numeric_bold=$NBFONT"
fetch_weather

lipc-set-prop com.lab126.powerd preventScreenSaver 1 >/dev/null 2>&1
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
case "$MODE" in
  preview-dayparts) VIEW_MODE=1 ;;
  preview-daily) VIEW_MODE=2 ;;
  preview|preview-hourly) VIEW_MODE=0 ;;
esac
draw_dashboard

case "$MODE" in
  preview|preview-hourly|preview-dayparts|preview-daily)
    suspend_for "$PREVIEW_SECONDS"
    sleep 3
    /sbin/reboot
    exit 0
    ;;
esac

while true; do
  WAIT_SECS="$(seconds_until_next_hour)"
  log "next aligned refresh in ${WAIT_SECS}s"
  suspend_for "$WAIT_SECS"
  if [ "$RESUME_REASON" = "external-early" ]; then
    clean_exit
    exit 0
  fi
  # Give Wi-Fi a few seconds after RTC wake, then fetch current data.
  sleep 12
  if fetch_weather; then
    if [ "$MODE" = "live-hourly" ]; then
      VIEW_MODE=0
      log "forecast view fixed at hourly mode"
    else
      VIEW_MODE=$(((VIEW_MODE + 1) % 3))
      log "forecast view advanced to mode=$VIEW_MODE"
    fi
  fi
  draw_dashboard
done
