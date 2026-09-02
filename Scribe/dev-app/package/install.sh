#!/bin/sh

set -e

BASE="/mnt/us/ForecastInk"
CONFIG_SOURCE="./config.conf"
CONFIG_DESTINATION="$BASE/config.conf"
SCRIPTLET_SOURCE="./scriptlets/forecastink_scribe_dev.sh"
SCRIPTLET_DESTINATION="/mnt/us/documents/forecastink_scribe_dev.sh"

mkdir -p "$BASE/cache" "$BASE/logs"

if [ ! -e "$CONFIG_DESTINATION" ]; then
    if [ ! -f "$CONFIG_SOURCE" ]; then
        echo "ForecastInk Scribe Dev: packaged default config is missing." >&2
        exit 1
    fi
    cp "$CONFIG_SOURCE" "$CONFIG_DESTINATION"
    chmod 644 "$CONFIG_DESTINATION"
    echo "ForecastInk Scribe Dev default config created at $CONFIG_DESTINATION"
else
    echo "ForecastInk Scribe Dev: preserving existing config at $CONFIG_DESTINATION"
fi

if [ ! -f "$SCRIPTLET_SOURCE" ]; then
    echo "ForecastInk Scribe Dev: packaged scriptlet is missing." >&2
    exit 1
fi

if [ -e "$SCRIPTLET_DESTINATION" ] && ! cmp -s "$SCRIPTLET_SOURCE" "$SCRIPTLET_DESTINATION"; then
    echo "ForecastInk Scribe Dev: refusing to overwrite a different scriptlet at $SCRIPTLET_DESTINATION." >&2
    exit 1
fi

cp "$SCRIPTLET_SOURCE" "$SCRIPTLET_DESTINATION"
chmod 755 "$SCRIPTLET_DESTINATION"

echo "ForecastInk Scribe Dev scriptlet installed at $SCRIPTLET_DESTINATION"
