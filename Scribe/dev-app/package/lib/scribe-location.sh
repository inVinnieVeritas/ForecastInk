#!/bin/sh

# Location resolution adapted from ForecastInk's existing location semantics.
GEOCODE_CACHE="$BASE/cache/location.json"
GEOCODE_CACHE_QUERY="$BASE/cache/location.query"
GEOCODE_TMP="$BASE/cache/location-latest.json"
LOCATION_READY=0
LOCATION_SOURCE=""
RESOLVED_NAME=""
RESOLVED_COUNTRY=""
RESOLVED_REGION=""

location_log() {
    scribe_log "$*"
}

valid_coordinates() {
    awk -v lat="$1" -v lon="$2" 'BEGIN {
        number = "^-?[0-9]+([.][0-9]+)?$"
        if (lat !~ number || lon !~ number) exit 1
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) exit 1
    }'
}

valid_timezone() {
    case "$1" in
        ''|*[!A-Za-z0-9_+./-]*) return 1 ;;
        *) return 0 ;;
    esac
}

geocode_string() {
    key="$1"
    source_file="$2"
    tr -d '\r\n' <"$source_file" 2>/dev/null |
        sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" |
        head -n 1
}

geocode_number() {
    key="$1"
    source_file="$2"
    tr -d '\r\n' <"$source_file" 2>/dev/null |
        sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\([-0-9.][0-9.]*\).*/\1/p" |
        head -n 1
}

load_geocode_result() {
    source_file="$1"
    [ -s "$source_file" ] || return 1

    GEO_LATITUDE="$(geocode_number latitude "$source_file")"
    GEO_LONGITUDE="$(geocode_number longitude "$source_file")"
    GEO_TIMEZONE="$(geocode_string timezone "$source_file")"
    GEO_NAME="$(geocode_string name "$source_file")"
    GEO_COUNTRY="$(geocode_string country "$source_file")"
    GEO_REGION="$(geocode_string admin1 "$source_file")"

    valid_coordinates "$GEO_LATITUDE" "$GEO_LONGITUDE" || return 1
    valid_timezone "$GEO_TIMEZONE" || return 1

    LATITUDE="$GEO_LATITUDE"
    LONGITUDE="$GEO_LONGITUDE"
    TIMEZONE="$GEO_TIMEZONE"
    RESOLVED_NAME="$GEO_NAME"
    RESOLVED_COUNTRY="$GEO_COUNTRY"
    RESOLVED_REGION="$GEO_REGION"
}

cache_query_matches() {
    [ -s "$GEOCODE_CACHE" ] && [ -f "$GEOCODE_CACHE_QUERY" ] || return 1
    IFS= read -r cached_location <"$GEOCODE_CACHE_QUERY" || return 1
    [ "$cached_location" = "$LOCATION" ]
}

save_geocode_cache() {
    source_file="$1"
    json_new="${GEOCODE_CACHE}.new"
    query_new="${GEOCODE_CACHE_QUERY}.new"

    cp "$source_file" "$json_new" 2>/dev/null || return 1
    printf '%s\n' "$LOCATION" >"$query_new" 2>/dev/null || {
        rm -f "$json_new"
        return 1
    }
    mv "$json_new" "$GEOCODE_CACHE" 2>/dev/null || return 1
    mv "$query_new" "$GEOCODE_CACHE_QUERY" 2>/dev/null || return 1
}

normalize_geocode_query() {
    case "$1" in
        *", UK") printf '%s, United Kingdom' "${1%, UK}" ;;
        *", Uk") printf '%s, United Kingdom' "${1%, Uk}" ;;
        *", uK") printf '%s, United Kingdom' "${1%, uK}" ;;
        *", uk") printf '%s, United Kingdom' "${1%, uk}" ;;
        *) printf '%s' "$1" ;;
    esac
}

geocode_lookup() {
    geocode_query="$(normalize_geocode_query "$LOCATION")"
    [ "$geocode_query" = "$LOCATION" ] || location_log "geocoding_normalized_query=$geocode_query"
    rm -f "$GEOCODE_TMP"
    "$XH" -d -q -o "$GEOCODE_TMP" get \
        "https://geocoding-api.open-meteo.com/v1/search" \
        "name==$geocode_query" count==1 language==en format==json
}

resolve_location() {
    [ "$LOCATION_READY" = "1" ] && return 0

    if [ -n "$LATITUDE" ] && [ -n "$LONGITUDE" ] && [ -n "$TIMEZONE" ]; then
        if valid_coordinates "$LATITUDE" "$LONGITUDE" && valid_timezone "$TIMEZONE"; then
            LOCATION_READY=1
            LOCATION_SOURCE="explicit"
            location_log "location_source=explicit"
            return 0
        fi
        location_log "explicit_location_invalid=true"
    elif [ -n "$LATITUDE$LONGITUDE$TIMEZONE" ]; then
        location_log "explicit_location_incomplete=true"
    fi

    if [ -z "$LOCATION" ]; then
        location_log "location_error=empty"
        return 1
    fi

    if cache_query_matches && load_geocode_result "$GEOCODE_CACHE"; then
        LOCATION_READY=1
        LOCATION_SOURCE="cache"
        location_log "location_source=cache"
        return 0
    fi

    location_log "geocoding_request_start=true query=$LOCATION"
    geocode_lookup >>"$SCRIBE_LOG_FILE" 2>&1
    geocode_rc=$?
    geocode_bytes=0
    [ -f "$GEOCODE_TMP" ] && geocode_bytes="$(wc -c <"$GEOCODE_TMP")"
    location_log "geocoding_return_code=$geocode_rc downloaded_bytes=$geocode_bytes"

    if [ "$geocode_rc" -eq 0 ] && load_geocode_result "$GEOCODE_TMP"; then
        LOCATION_READY=1
        LOCATION_SOURCE="geocoding"
        if save_geocode_cache "$GEOCODE_TMP"; then
            location_log "location_cache_updated=true"
        else
            location_log "location_cache_updated=false"
        fi
        return 0
    fi

    if cache_query_matches && load_geocode_result "$GEOCODE_CACHE"; then
        LOCATION_READY=1
        LOCATION_SOURCE="cache-fallback"
        location_log "location_source=cache-fallback"
        return 0
    fi

    location_log "location_error=geocoding_failed"
    return 1
}
