#!/bin/sh

set -e

SCRIPTLET_SOURCE="./scriptlets/forecastink_scribe_probe.sh"
SCRIPTLET_DESTINATION="/mnt/us/documents/forecastink_scribe_probe.sh"

if [ ! -f "$SCRIPTLET_SOURCE" ]; then
    echo "ForecastInk Scribe Probe: packaged scriptlet is missing." >&2
    exit 1
fi

if [ -e "$SCRIPTLET_DESTINATION" ] && ! cmp -s "$SCRIPTLET_SOURCE" "$SCRIPTLET_DESTINATION"; then
    echo "ForecastInk Scribe Probe: refusing to overwrite a different scriptlet at $SCRIPTLET_DESTINATION." >&2
    exit 1
fi

cp "$SCRIPTLET_SOURCE" "$SCRIPTLET_DESTINATION"
chmod 755 "$SCRIPTLET_DESTINATION"

echo "ForecastInk Scribe Probe scriptlet installed at $SCRIPTLET_DESTINATION"

