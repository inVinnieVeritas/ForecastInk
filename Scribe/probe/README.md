# ForecastInk Scribe proof-of-life probe

This directory contains a diagnostic-only KPM package for the Kindle Scribe
(1st generation, 2022), firmware 5.19.5. It targets the `kindlehf` KPM
platform and does not render to or configure the framebuffer.

The package layout follows the current KindleModding KPM conventions:

- `manifest.json` uses the current manifest format.
- `install.sh`, `launch.sh`, and `uninstall.sh` are POSIX `sh` hooks at the
  package root.
- The package installs and owns its scriptlet in `/mnt/us/documents/`.
- The scriptlet launches the package through `/var/local/kmc/bin/kpm`, without
  depending on KPM's internal package storage path.

To build with the official `KindleModding/KPM` helper, place the current
`kpm-helper.py` outside `package/` and run:

```sh
python kpm-helper.py package pack package dist
```

The generated `dist/` directory is intentionally ignored.

