#!/bin/sh

# KUAL safety fallback for live ForecastInk modes.
BASE="/mnt/us/extensions/ForecastInk"
RECOVERY_LOG="$BASE/cache/forecastink.log"
RECOVERY_TMP_LOG="/tmp/forecastink-resume.log"
FORECASTINK_PID_FILE="/tmp/forecastink.pid"
FORECASTINK_RTC_FILE="/tmp/forecastink-rtc-path"

mkdir -p "$BASE/cache" 2>/dev/null || true
recovery_log(){
  RECOVERY_MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') $*"
  printf '%s\n' "$RECOVERY_MESSAGE" >>"$RECOVERY_TMP_LOG" 2>/dev/null || true
  printf '%s\n' "$RECOVERY_MESSAGE" >>"$RECOVERY_LOG" 2>/dev/null || true
}

cancel_forecastink_rtc(){
  RECOVERY_RTC_PATH=""
  if [ -r "$FORECASTINK_RTC_FILE" ]; then
    IFS= read -r RECOVERY_RTC_PATH <"$FORECASTINK_RTC_FILE" || RECOVERY_RTC_PATH=""
  fi
  case "$RECOVERY_RTC_PATH" in
    /sys/class/rtc/rtc0/wakealarm|/sys/class/rtc/rtc1/wakealarm)
      [ -e "$RECOVERY_RTC_PATH" ] && echo 0 >"$RECOVERY_RTC_PATH" 2>/dev/null || true
      ;;
  esac
  rm -f "$FORECASTINK_RTC_FILE" 2>/dev/null || true
}

stop_forecastink(){
  [ -r "$FORECASTINK_PID_FILE" ] || return 0
  IFS= read -r RECOVERY_PID <"$FORECASTINK_PID_FILE" || RECOVERY_PID=""
  case "$RECOVERY_PID" in ''|*[!0-9]*) return 0 ;; esac
  [ -r "/proc/$RECOVERY_PID/cmdline" ] || return 0
  RECOVERY_CMDLINE="$(tr '\000' ' ' <"/proc/$RECOVERY_PID/cmdline" 2>/dev/null)"
  case "$RECOVERY_CMDLINE" in
    *forecastink-run*) kill "$RECOVERY_PID" 2>/dev/null || true ;;
    *) recovery_log "recovery ignored stale ForecastInk pid=$RECOVERY_PID"; return 0 ;;
  esac

  RECOVERY_WAIT=0
  while kill -0 "$RECOVERY_PID" 2>/dev/null && [ "$RECOVERY_WAIT" -lt 3 ]; do
    sleep 1
    RECOVERY_WAIT=$((RECOVERY_WAIT + 1))
  done
  if kill -0 "$RECOVERY_PID" 2>/dev/null; then
    kill -KILL "$RECOVERY_PID" 2>/dev/null || true
  fi
}

recovery_log "recovery starting"
cancel_forecastink_rtc
stop_forecastink

RECOVERY_LAB_RC=0
if [ -x /sbin/status ] && /sbin/status lab126_gui 2>/dev/null | grep -q 'start/running'; then
  RECOVERY_LAB_RC=0
elif [ -x /sbin/start ]; then
  (cd / && /sbin/start lab126_gui) >/dev/null 2>&1
  RECOVERY_LAB_RC=$?
  sleep 2
elif [ -x /etc/init.d/framework ]; then
  (cd / && /etc/init.d/framework start) >/dev/null 2>&1
  RECOVERY_LAB_RC=$?
  sleep 2
else
  RECOVERY_LAB_RC=127
fi
recovery_log "lab126_gui ensure rc=$RECOVERY_LAB_RC"

RECOVERY_PILLOW_RC=127
if [ -x /usr/bin/lipc-set-prop ]; then
  /usr/bin/lipc-set-prop com.lab126.pillow interrogatePillow \
    '{"pillowId": "default_status_bar", "function": "nativeBridge.showMe();"}' \
    >/dev/null 2>&1
  RECOVERY_PILLOW_RC=$?
fi
recovery_log "pillow show rc=$RECOVERY_PILLOW_RC"

RECOVERY_HOME_RC=127
if [ -x /usr/bin/lipc-set-prop ]; then
  /usr/bin/lipc-set-prop com.lab126.appmgrd start \
    app://com.lab126.booklet.home >/dev/null 2>&1
  RECOVERY_HOME_RC=$?
fi
recovery_log "home request rc=$RECOVERY_HOME_RC"

rm -f "$FORECASTINK_PID_FILE" 2>/dev/null || true

# This must remain the final Kindle restoration operation.
RECOVERY_PREVENT_RC=127
if [ -x /usr/bin/lipc-set-prop ]; then
  /usr/bin/lipc-set-prop com.lab126.powerd preventScreenSaver 0 >/dev/null 2>&1
  RECOVERY_PREVENT_RC=$?
fi
recovery_log "preventScreenSaver=0 rc=$RECOVERY_PREVENT_RC"
recovery_log "recovery complete"
