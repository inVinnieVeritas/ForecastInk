#!/bin/sh

SCRIPTLET_SOURCE="./scriptlets/forecastink_scribe_dev.sh"
SCRIPTLET_DESTINATION="/mnt/us/documents/forecastink_scribe_dev.sh"

if [ ! -e "$SCRIPTLET_DESTINATION" ]; then
    echo "ForecastInk Scribe Dev scriptlet is already absent."
elif [ -f "$SCRIPTLET_SOURCE" ] && cmp -s "$SCRIPTLET_SOURCE" "$SCRIPTLET_DESTINATION"; then
    rm -f "$SCRIPTLET_DESTINATION"
    echo "ForecastInk Scribe Dev scriptlet removed."
else
    echo "ForecastInk Scribe Dev: preserving a scriptlet that does not match this package." >&2
fi

# Development logs are intentionally retained for inspection.
exit 0

