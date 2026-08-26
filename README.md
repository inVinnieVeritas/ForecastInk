# PaperCast

Turn an old jailbroken Kindle Paperwhite into a low-power e-ink weather dashboard.

![PaperCast running on a Kindle Paperwhite 1](assets/papercast-real-device.jpg)

PaperCast repurposes an old Kindle Paperwhite as a dedicated weather display. It fetches weather data, renders a clean portrait dashboard directly to the e-ink screen, then puts the Kindle back into deep sleep until the next scheduled refresh.

## Current features

- Current temperature and weather conditions
- Feels-like temperature
- Precipitation probability
- Precipitation amount in millimetres
- Daily high and low
- Sunrise and sunset
- Next-hours forecast
- Daypart forecast
- Multi-day forecast
- Cycling forecast views
- Direct previews for the Hourly, Dayparts, Daily, and all-views screens
- Meteocons monochrome weather icons
- Battery level
- Last-refreshed time
- Automatic hourly refresh
- Deep sleep between updates

## Real-device preview

This is PaperCast running on the Kindle Paperwhite 1 used during development:

![PaperCast running on a Kindle Paperwhite 1](assets/papercast-real-device.jpg)

The interface is designed specifically for e-ink rather than adapted from a phone or desktop weather app. The Kindle spends most of its time suspended and wakes only when it needs to update.

## How it works

PaperCast uses Open-Meteo weather data with the DWD ICON Seamless forecast model. FBInk renders the dashboard directly to the Kindle framebuffer, while RTC wake alarms provide the hourly update schedule.

A normal update cycle is:

1. Wake the Kindle using its RTC alarm
2. Allow Wi-Fi to reconnect
3. Fetch current conditions and forecast data
4. Render the selected forecast view
5. Suspend until the next hourly refresh

Because an e-ink display requires essentially no power to retain a static image, an old Kindle is unusually well suited to this job.

## Tested hardware

The v0.9.1 public beta has been physically tested with:

- Kindle Paperwhite 1
- Firmware 5.6.1.1
- KUAL
- FBInk
- Wi-Fi weather updates
- Hourly RTC suspend/wake cycles

## Current status

PaperCast is a public beta release. The current known-good build is **v0.9.1**.

It includes Hourly, Dayparts, and four-day forecast views. Precipitation probability and precipitation amount are shown in the current conditions and forecast views where corresponding Open-Meteo data is available.

## Requirements

- A jailbroken Kindle
- [KUAL](https://www.mobileread.com/forums/showthread.php?t=203326)
- Kindle Paperwhite 1 for the currently tested hardware target
- Firmware 5.6.1.1 for the currently tested firmware target

PaperCast may work on other jailbroken Kindle models or firmware versions, but they have not yet been validated.

## Installation

1. Download and extract `PaperCast-v0.9.1.zip`.
2. Copy the top-level `KindleDash/` extension directory to `/mnt/us/extensions/` on the Kindle.
3. Confirm that the installed menu file is at `/mnt/us/extensions/KindleDash/menu.json` and the launcher is at `/mnt/us/extensions/KindleDash/bin/run.sh`.
4. Safely disconnect the Kindle, open KUAL, and select **PaperCast**.
5. Choose a direct preview action, **Start PaperCast — Hourly only**, or **Start PaperCast — Cycle all 3 views**.

The project and public release are named PaperCast, but the tested runtime directory is still named `KindleDash`. Do not rename that directory: current scripts contain `/mnt/us/extensions/KindleDash` runtime paths.

## Configuration

Edit `/mnt/us/extensions/KindleDash/config.conf` before starting live mode. The currently supported manual settings are:

| Setting | Purpose | Example |
|---|---|---|
| `LOCATION` | Label displayed on the dashboard | `Brussels` |
| `LATITUDE` | Forecast latitude in decimal degrees | `50.87002` |
| `LONGITUDE` | Forecast longitude in decimal degrees | `4.40824` |
| `TIMEZONE` | IANA timezone used for API data and display times | `Europe/Brussels` |

The checked-in development configuration uses the Evere coordinates below while retaining Brussels as the visible location label:

```conf
LOCATION="Brussels"
LATITUDE="50.87002"
LONGITUDE="4.40824"
TIMEZONE="Europe/Brussels"
```

City-name-only automatic configuration is planned but is not implemented. A location change currently requires manually updating all applicable values.

## Weather data

PaperCast uses:

- Open-Meteo for weather data and forecast delivery
- DWD ICON Seamless as the selected forecast model

The displayed current temperature and conditions are model-derived weather data. They are not measurements from a physical sensor attached to the Kindle, so they can differ from nearby weather stations or other services—especially during rapidly changing conditions.

## Current limitations

- Currently optimized and tested only on Kindle Paperwhite 1
- Portrait orientation only
- Clean exit back to the standard Kindle interface is still planned
- User-friendly city-only configuration is still planned
- Current conditions are model-derived rather than measured by a local physical sensor
- Other Kindle models have not yet been validated

## Roadmap

- Clean exit back to the standard Kindle interface
- City-only automatic location setup
- Landscape mode
- Additional Kindle model testing
- Public installation cleanup

## Project philosophy

PaperCast is deliberately simple: reuse hardware that might otherwise sit in a drawer and turn it into a quiet, low-power information display.

No browser. No glowing LCD. No constant animation. Just weather on e-ink.

## Credits and attribution

PaperCast builds on excellent open-source projects and public weather services:

- [Open-Meteo](https://open-meteo.com/) — weather API and forecast delivery; API data are licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- [DWD ICON](https://www.dwd.de/EN/ourservices/nwp_forecast_data/nwp_forecast_data.html) — forecast model data produced by © Deutscher Wetterdienst
- [FBInk](https://github.com/NiLuJe/FBInk) — Kindle framebuffer rendering, licensed GPL-3.0-or-later
- [Meteocons](https://github.com/basmilius/meteocons) — monochrome weather icon source, licensed MIT

Weather data by [Open-Meteo.com](https://open-meteo.com/) (CC BY 4.0), adapted for display by PaperCast. Forecast model data are based on DWD ICON Seamless, © Deutscher Wetterdienst.

## License

PaperCast's original source code, documentation, and project-owned artwork are licensed under the [MIT License](LICENSE). Bundled third-party binaries and artwork retain their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for exact versions, source links, notices, and data-attribution requirements.
