#!/bin/sh

SCRIBE_SCREEN_WIDTH=1860
SCRIBE_SCREEN_HEIGHT=2480
SCRIBE_LOG_FILE=""
SCRIBE_DEVICE_MODEL=""
SCRIBE_ARCHITECTURE=""
SCRIBE_FBINK=""

scribe_log_init() {
    log_file="$1"
    log_directory="${log_file%/*}"

    if [ -z "$log_file" ] || [ "$log_directory" = "$log_file" ]; then
        return 1
    fi

    mkdir -p "$log_directory" || return 1
    : >"$log_file" || return 1
    SCRIBE_LOG_FILE="$log_file"
}

scribe_log() {
    [ -n "$SCRIBE_LOG_FILE" ] || return 1
    printf '%s\n' "$1" >>"$SCRIBE_LOG_FILE"
}

scribe_detect_device() {
    SCRIBE_DEVICE_MODEL=""

    for model_file in \
        "/proc/device-tree/model" \
        "/sys/firmware/devicetree/base/model"
    do
        [ -r "$model_file" ] || continue
        candidate_model="$(tr -d '\000' <"$model_file" 2>/dev/null)"
        [ -n "$candidate_model" ] || continue
        SCRIBE_DEVICE_MODEL="$candidate_model"

        case "$SCRIBE_DEVICE_MODEL" in
            *"Kindle Scribe"*) return 0 ;;
        esac
    done

    return 1
}

scribe_detect_architecture() {
    SCRIBE_ARCHITECTURE="$(uname -m 2>/dev/null)"
    [ "$SCRIBE_ARCHITECTURE" = "armv7l" ]
}

scribe_discover_fbink() {
    SCRIBE_FBINK=""

    if [ -x "/var/local/kmc/bin/fbink" ]; then
        SCRIBE_FBINK="/var/local/kmc/bin/fbink"
    elif [ -x "/mnt/us/libkh/bin/fbink" ]; then
        SCRIBE_FBINK="/mnt/us/libkh/bin/fbink"
    else
        return 1
    fi
}

scribe_log_file_value() {
    label="$1"
    value_file="$2"

    if [ -r "$value_file" ]; then
        value="$(cat "$value_file" 2>/dev/null)"
        scribe_log "$label=${value:-unavailable}"
    else
        scribe_log "$label=unavailable"
    fi
}

scribe_log_framebuffer_info() {
    if [ -e "/dev/fb0" ]; then
        scribe_log "framebuffer_device=/dev/fb0"
    else
        scribe_log "framebuffer_device=unavailable"
    fi

    scribe_log_file_value "fb0_name" "/sys/class/graphics/fb0/name"
    scribe_log_file_value "fb0_virtual_size" "/sys/class/graphics/fb0/virtual_size"
    scribe_log_file_value "fb0_bits_per_pixel" "/sys/class/graphics/fb0/bits_per_pixel"
    scribe_log_file_value "fb0_stride" "/sys/class/graphics/fb0/stride"
    scribe_log_file_value "fb0_rotate" "/sys/class/graphics/fb0/rotate"
}

