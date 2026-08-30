#!/bin/sh

# Resume classification shared by the PaperCast runtime and deterministic tests.
WAKE_TOLERANCE_SECONDS="${WAKE_TOLERANCE_SECONDS:-90}"

resume_delta() {
  EXPECTED_EPOCH="$1"
  ACTUAL_EPOCH="$2"
  case "$EXPECTED_EPOCH" in ''|*[!0-9]*) return 2 ;; esac
  case "$ACTUAL_EPOCH" in ''|*[!0-9]*) return 2 ;; esac
  echo $((ACTUAL_EPOCH - EXPECTED_EPOCH))
}

classify_resume() {
  EXPECTED_EPOCH="$1"
  ACTUAL_EPOCH="$2"
  TOLERANCE_SECONDS="${3:-$WAKE_TOLERANCE_SECONDS}"
  case "$EXPECTED_EPOCH" in ''|*[!0-9]*) return 2 ;; esac
  case "$ACTUAL_EPOCH" in ''|*[!0-9]*) return 2 ;; esac
  case "$TOLERANCE_SECONDS" in ''|*[!0-9]*) return 2 ;; esac

  DELTA_SECONDS=$((ACTUAL_EPOCH - EXPECTED_EPOCH))
  if [ "$DELTA_SECONDS" -lt $((0 - TOLERANCE_SECONDS)) ]; then
    echo "external-early"
  else
    echo "rtc"
  fi
}
