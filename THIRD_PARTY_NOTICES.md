# Third-Party Notices

ForecastInk's original source code, documentation, and project-owned artwork are licensed under the MIT License in [`LICENSE`](LICENSE). The components and data sources below are not relicensed by ForecastInk; their own terms continue to apply.

## Bundled software

### FBInk v1.25.0 for Kindle

Bundled paths:

- `fbink/bin/fbink`
- `fbink/lib/libfbink.so.1.0.0`
- `fbink/lib/libfbink.so.1`
- `fbink/lib/libfbink.so`

FBInk is Copyright (c) NiLuJe and contributors and is licensed under the GNU General Public License, version 3 or (at your option) any later version (`GPL-3.0-or-later`). ForecastInk invokes the FBInk command-line executable as a separate program. ForecastInk does not link its own source code to the bundled shared library.

The bundled executable and shared library identify themselves as `v1.25.0 for Kindle`.

- Project: https://github.com/NiLuJe/FBInk
- Exact source release: https://github.com/NiLuJe/FBInk/releases/tag/v1.25.0
- Corresponding-source archive: https://github.com/NiLuJe/FBInk/releases/download/v1.25.0/FBInk-v1.25.0.tar.xz
- License copy: [`licenses/FBInk-GPL-3.0-or-later.txt`](licenses/FBInk-GPL-3.0-or-later.txt)
- Upstream credits and embedded-component notices: [`licenses/FBInk-CREDITS.txt`](licenses/FBInk-CREDITS.txt)

The source archive above contains FBInk's build scripts and the source and notices for its embedded libraries, routines, and bitmap fonts. Anyone redistributing the FBInk object code must continue to provide equivalent access to the complete corresponding source, retain notices, and provide the GPL license as required by GPLv3 section 6.

### xh 0.16.1

Bundled path: `bin/xh`

xh is Copyright (c) 2021 Mohamed Daahir and is licensed under the MIT License.

- Project: https://github.com/ducaale/xh
- Source release: https://github.com/ducaale/xh/tree/v0.16.1
- License copy: [`licenses/xh-MIT.txt`](licenses/xh-MIT.txt)
- Embedded dependency inventory: [`licenses/xh-0.16.1-dependencies.md`](licenses/xh-0.16.1-dependencies.md)

The bundled executable identifies itself as `xh/0.16.1`. Its SHA-256 is `d77c9b66a5bcd2ef0375d922b7f709f8ce4697a9d57c4b2452d6cb7ce6eaef70`. It is not byte-for-byte identical to the official v0.16.1 ARM release executable, so it is described here as a separately built copy rather than an official upstream binary. The MIT license permits redistribution of modified or independently built copies when its copyright and permission notice are retained. The executable statically incorporates Rust crates and runtime code under permissive licenses; the inventory records the exact crate versions and license expressions found in the binary. Custom license texts required by its `ring`/WebPKI TLS stack are included under `licenses/`.

## Bundled artwork

### Meteocons by Bas Milius

The nine hero icons under `assets/hero/` and the corresponding nine forecast icons under `assets/weather/` are raster adaptations of the Meteocons monochrome static SVG artwork. They cover `clear`, `clear-night`, `partly`, `partly-night`, `cloudy`, `fog`, `rain`, `snow`, and `thunder`.

Meteocons is Copyright (c) 2020-present Bas Milius and is licensed under the MIT License. ForecastInk's copies were rendered to PNG, normalized to the existing canvases, and optically strengthened for e-ink display.

- Project: https://github.com/basmilius/meteocons
- License copy: [`licenses/Meteocons-MIT.txt`](licenses/Meteocons-MIT.txt)

No other tracked image or binary asset contains an embedded third-party license notice. The remaining dashboard artwork, digit assets, and README images are treated as ForecastInk project/user-supplied material. Their provenance should remain documented if any of them are replaced in the future.

## Services and weather data

These are network services/data sources, not code distributed under ForecastInk's MIT License.

### Open-Meteo

Weather and forecast data are delivered by Open-Meteo. Open-Meteo API data are licensed under the Creative Commons Attribution 4.0 International License (`CC BY 4.0`). Attribution must name Open-Meteo, link to Open-Meteo and the license, and indicate modifications.

- Provider: https://open-meteo.com/
- Data license and attribution requirements: https://open-meteo.com/en/license
- License: https://creativecommons.org/licenses/by/4.0/

ForecastInk selects, rounds, aggregates, labels, and renders values returned by the API. Those transformations are modifications for attribution purposes.

Suggested attribution:

> Weather data by Open-Meteo.com (CC BY 4.0), adapted for display by ForecastInk.

### DWD ICON Seamless

ForecastInk explicitly requests the DWD ICON Seamless forecast model through Open-Meteo. The underlying model data are produced by the Deutscher Wetterdienst (DWD). DWD open geodata may be reused with a source note under DWD's open-data terms/GeoNutzV; Open-Meteo's delivered API dataset remains subject to Open-Meteo's CC BY 4.0 attribution terms above.

- DWD ICON information: https://www.dwd.de/EN/ourservices/nwp_forecast_data/nwp_forecast_data.html
- DWD open-data information: https://www.dwd.de/EN/ourservices/opendata/opendata.html
- DWD copyright/source-note information: https://www.dwd.de/EN/service/copyright/copyright_artikel.html

Suggested source note:

> Forecast model data based on DWD ICON Seamless, © Deutscher Wetterdienst; delivered by Open-Meteo and adapted by ForecastInk.

## Trademarks and platform dependencies

Kindle and Kindle Paperwhite are trademarks of Amazon. KUAL is a separately installed platform dependency and is not bundled in this repository. Kindle firmware fonts and system utilities are referenced at runtime but are not redistributed by ForecastInk.
