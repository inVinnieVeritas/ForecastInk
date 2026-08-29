#!/bin/sh

# Automatic location resolution for PaperCast.
# Expects BASE, XH, LOCATION, LATITUDE, LONGITUDE and TIMEZONE from run.sh.

GEOCODE_CACHE="$BASE/cache/location.json"
GEOCODE_CACHE_QUERY="$BASE/cache/location.query"
GEOCODE_TMP="$BASE/cache/location-latest.json"
LOCATION_READY=0
LOCATION_SOURCE=""
RESOLVED_NAME=""
RESOLVED_COUNTRY=""
RESOLVED_REGION=""

location_log(){
  command -v log >/dev/null 2>&1 && log "$*"
}

valid_coordinates(){
  awk -v lat="$1" -v lon="$2" 'BEGIN {
    number = "^-?[0-9]+([.][0-9]+)?$"
    if (lat !~ number || lon !~ number) exit 1
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) exit 1
  }'
}

valid_timezone(){
  case "$1" in
    ''|*[!A-Za-z0-9_+./-]*) return 1 ;;
    *) return 0 ;;
  esac
}

geocode_string(){
  KEY="$1"
  FILE="$2"
  tr -d '\r\n' <"$FILE" 2>/dev/null |
    sed -n "s/.*\"$KEY\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" |
    head -n 1
}

geocode_number(){
  KEY="$1"
  FILE="$2"
  tr -d '\r\n' <"$FILE" 2>/dev/null |
    sed -n "s/.*\"$KEY\"[[:space:]]*:[[:space:]]*\([-0-9.][0-9.]*\).*/\1/p" |
    head -n 1
}

load_geocode_result(){
  FILE="$1"
  [ -s "$FILE" ] || return 1

  GEO_LATITUDE="$(geocode_number latitude "$FILE")"
  GEO_LONGITUDE="$(geocode_number longitude "$FILE")"
  GEO_TIMEZONE="$(geocode_string timezone "$FILE")"
  GEO_NAME="$(geocode_string name "$FILE")"
  GEO_COUNTRY="$(geocode_string country "$FILE")"
  GEO_REGION="$(geocode_string admin1 "$FILE")"

  valid_coordinates "$GEO_LATITUDE" "$GEO_LONGITUDE" || return 1
  valid_timezone "$GEO_TIMEZONE" || return 1

  LATITUDE="$GEO_LATITUDE"
  LONGITUDE="$GEO_LONGITUDE"
  TIMEZONE="$GEO_TIMEZONE"
  RESOLVED_NAME="$GEO_NAME"
  RESOLVED_COUNTRY="$GEO_COUNTRY"
  RESOLVED_REGION="$GEO_REGION"
  return 0
}

cache_query_matches(){
  [ -s "$GEOCODE_CACHE" ] && [ -f "$GEOCODE_CACHE_QUERY" ] || return 1
  IFS= read -r CACHED_LOCATION <"$GEOCODE_CACHE_QUERY" || return 1
  [ "$CACHED_LOCATION" = "$LOCATION" ]
}

save_geocode_cache(){
  SOURCE_FILE="$1"
  JSON_NEW="${GEOCODE_CACHE}.new"
  QUERY_NEW="${GEOCODE_CACHE_QUERY}.new"

  cp "$SOURCE_FILE" "$JSON_NEW" 2>/dev/null || return 1
  printf '%s\n' "$LOCATION" >"$QUERY_NEW" 2>/dev/null || {
    rm -f "$JSON_NEW"
    return 1
  }
  mv "$JSON_NEW" "$GEOCODE_CACHE" 2>/dev/null || return 1
  mv "$QUERY_NEW" "$GEOCODE_CACHE_QUERY" 2>/dev/null || return 1
  return 0
}

normalize_geocode_query(){
  case "$1" in
    *", UK") printf '%s, United Kingdom' "${1%, UK}" ;;
    *", Uk") printf '%s, United Kingdom' "${1%, Uk}" ;;
    *", uK") printf '%s, United Kingdom' "${1%, uK}" ;;
    *", uk") printf '%s, United Kingdom' "${1%, uk}" ;;
    *) printf '%s' "$1" ;;
  esac
}

geocode_lookup(){
  GEOCODE_QUERY="$(normalize_geocode_query "$LOCATION")"
  if [ "$GEOCODE_QUERY" != "$LOCATION" ]; then
    location_log "geocoding normalized query='$GEOCODE_QUERY'"
  fi
  rm -f "$GEOCODE_TMP"
  "$XH" -d -q -o "$GEOCODE_TMP" get \
    "https://geocoding-api.open-meteo.com/v1/search" \
    "name==$GEOCODE_QUERY" count==1 language==en format==json
}
resolve_location(){
  [ "$LOCATION_READY" = "1" ] && return 0

  LATITUDE="${LATITUDE:-}"
  LONGITUDE="${LONGITUDE:-}"
  TIMEZONE="${TIMEZONE:-}"
  LOCATION="${LOCATION:-}"

  if [ -n "$LATITUDE" ] && [ -n "$LONGITUDE" ] && [ -n "$TIMEZONE" ]; then
    if valid_coordinates "$LATITUDE" "$LONGITUDE" && valid_timezone "$TIMEZONE"; then
      LOCATION_READY=1
      LOCATION_SOURCE="explicit"
      location_log "location explicit latitude=$LATITUDE longitude=$LONGITUDE timezone=$TIMEZONE"
      return 0
    fi
    location_log "location explicit values invalid; attempting geocoding for '$LOCATION'"
  elif [ -n "$LATITUDE$LONGITUDE$TIMEZONE" ]; then
    location_log "location explicit override incomplete; resolving all values from '$LOCATION'"
  fi

  if [ -z "$LOCATION" ]; then
    location_log "location error: LOCATION is empty and no complete explicit override is available"
    return 1
  fi

  if cache_query_matches; then
    if load_geocode_result "$GEOCODE_CACHE"; then
      LOCATION_READY=1
      LOCATION_SOURCE="cache"
      location_log "location cache hit query='$LOCATION' latitude=$LATITUDE longitude=$LONGITUDE timezone=$TIMEZONE"
      return 0
    fi
    location_log "location cache invalid for '$LOCATION'; refreshing"
  elif [ -s "$GEOCODE_CACHE" ]; then
    location_log "location changed to '$LOCATION'; cached query will not be reused"
  fi

  location_log "geocoding lookup query='$LOCATION'"
  geocode_lookup >>"$LOG" 2>&1
  GEO_RC=$?
  GEO_BYTES=0
  [ -f "$GEOCODE_TMP" ] && GEO_BYTES="$(wc -c <"$GEOCODE_TMP")"

  if [ "$GEO_RC" -eq 0 ] && load_geocode_result "$GEOCODE_TMP"; then
    LOCATION_READY=1
    LOCATION_SOURCE="geocoding"
    location_log "geocoding resolved query='$LOCATION' name='$RESOLVED_NAME' region='$RESOLVED_REGION' country='$RESOLVED_COUNTRY' latitude=$LATITUDE longitude=$LONGITUDE timezone=$TIMEZONE"
    if save_geocode_cache "$GEOCODE_TMP"; then
      location_log "location cache updated query='$LOCATION'"
    else
      location_log "location cache write failed; using resolved location for this session"
    fi
    return 0
  fi

  if cache_query_matches && load_geocode_result "$GEOCODE_CACHE"; then
    LOCATION_READY=1
    LOCATION_SOURCE="cache-fallback"
    location_log "geocoding failed rc=$GEO_RC bytes=$GEO_BYTES; using valid cache for '$LOCATION'"
    return 0
  fi

  location_log "geocoding failed rc=$GEO_RC bytes=$GEO_BYTES for '$LOCATION'; no valid matching cache"
  return 1
}
