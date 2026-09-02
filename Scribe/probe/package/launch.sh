#!/bin/sh

LOG_DIRECTORY="/mnt/us/ForecastInk/logs"
LOG_FILE="$LOG_DIRECTORY/scribe-probe.log"

read_optional_file() {
    label="$1"
    path="$2"

    printf '%s (%s):\n' "$label" "$path"
    if [ -r "$path" ]; then
        cat "$path" 2>&1
    else
        echo "unavailable"
    fi
}

print_command_path() {
    command_name="$1"
    command_path="$(command -v "$command_name" 2>/dev/null)"

    if [ -n "$command_path" ]; then
        printf '%s=%s\n' "$command_name" "$command_path"
    else
        printf '%s=unavailable\n' "$command_name"
    fi
}

collect_probe() {
    echo "ForecastInk Scribe Probe 0.0.1"
    echo "expected_platform=kindlehf"
    echo "expected_display=1860x2480"

    echo
    echo "[basic]"
    printf 'date_time='; date 2>&1 || echo "unavailable"
    printf 'pwd='; pwd 2>&1 || echo "unavailable"
    printf 'id='; id 2>&1 || echo "unavailable"
    printf 'uname_a='; uname -a 2>&1 || echo "unavailable"
    printf 'uname_m='; uname -m 2>&1 || echo "unavailable"

    echo
    echo "[kpm environment]"
    printf 'KPM_PLATFORM=%s\n' "${KPM_PLATFORM:-unavailable}"
    if command -v env >/dev/null 2>&1; then
        env | while IFS= read -r environment_entry; do
            case "$environment_entry" in
                KPM_*) printf '%s\n' "$environment_entry" ;;
            esac
        done
    else
        echo "KPM_* listing unavailable: env command not found"
    fi

    echo
    echo "[firmware and device]"
    read_optional_file "pretty version" "/etc/prettyversion.txt"
    read_optional_file "version" "/etc/version.txt"
    read_optional_file "OS release" "/etc/os-release"
    read_optional_file "device-tree model" "/proc/device-tree/model"
    read_optional_file "firmware device-tree model" "/sys/firmware/devicetree/base/model"
    read_optional_file "SoC machine" "/sys/devices/soc0/machine"
    read_optional_file "SoC family" "/sys/devices/soc0/family"
    read_optional_file "SoC ID" "/sys/devices/soc0/soc_id"

    echo
    echo "[cpu]"
    if [ -r "/proc/cpuinfo" ] && command -v grep >/dev/null 2>&1; then
        grep -E '^(processor|model name|Hardware|Revision|CPU implementer|CPU architecture|CPU variant|CPU part|CPU revision|Features)[[:space:]]*:' /proc/cpuinfo 2>&1 || echo "matching cpuinfo fields unavailable"
    elif [ ! -r "/proc/cpuinfo" ]; then
        echo "/proc/cpuinfo unavailable"
    else
        echo "grep unavailable; cpuinfo not dumped"
    fi

    echo
    echo "[framebuffer discovery - read only]"
    read_optional_file "registered framebuffers" "/proc/fb"

    framebuffer_device_found=0
    for framebuffer_device in /dev/fb*; do
        [ -e "$framebuffer_device" ] || continue
        framebuffer_device_found=1
        if command -v ls >/dev/null 2>&1; then
            ls -l "$framebuffer_device" 2>&1
        else
            printf '%s exists (ls unavailable)\n' "$framebuffer_device"
        fi
    done
    if [ "$framebuffer_device_found" -eq 0 ]; then
        echo "/dev/fb*=unavailable"
    fi

    for framebuffer_property in name virtual_size bits_per_pixel stride rotate; do
        read_optional_file "fb0 $framebuffer_property" "/sys/class/graphics/fb0/$framebuffer_property"
    done

    print_command_path "fbink"
    print_command_path "fbset"

    echo
    echo "[/mnt/us filesystem]"
    if [ -r "/proc/mounts" ] && command -v grep >/dev/null 2>&1; then
        grep -E '[[:space:]]/mnt/us[[:space:]]' /proc/mounts 2>&1 || echo "/mnt/us mount entry unavailable"
    else
        echo "/proc/mounts or grep unavailable"
    fi

    if command -v df >/dev/null 2>&1; then
        df -h /mnt/us 2>&1 || echo "df data unavailable"
    else
        echo "df=unavailable"
    fi
}

if ! mkdir -p "$LOG_DIRECTORY"; then
    echo "ForecastInk Scribe Probe: could not create $LOG_DIRECTORY" >&2
    exit 1
fi

if command -v tee >/dev/null 2>&1; then
    collect_probe 2>&1 | tee "$LOG_FILE"
else
    collect_probe >"$LOG_FILE" 2>&1
    cat "$LOG_FILE"
fi

