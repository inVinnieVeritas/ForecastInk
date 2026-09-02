#!/bin/sh

SCRIPTLET_SOURCE="./scriptlets/forecastink_scribe_probe.sh"
SCRIPTLET_DESTINATION="/mnt/us/documents/forecastink_scribe_probe.sh"

if [ ! -e "$SCRIPTLET_DESTINATION" ]; then
    echo "ForecastInk Scribe Probe scriptlet is already absent."
elif [ -f "$SCRIPTLET_SOURCE" ] && cmp -s "$SCRIPTLET_SOURCE" "$SCRIPTLET_DESTINATION"; then
    rm -f "$SCRIPTLET_DESTINATION"
    echo "ForecastInk Scribe Probe scriptlet removed."
else
    echo "ForecastInk Scribe Probe: preserving a scriptlet that does not match this package." >&2
fi

# Probe logs are intentionally retained for user inspection.
exit 0

