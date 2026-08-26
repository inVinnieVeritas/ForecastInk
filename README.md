# PaperCast

Turn an old jailbroken Kindle Paperwhite into a low-power e-ink weather dashboard.

![PaperCast](assets/papercast-hero.png)

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

The v0.9.0 public beta has been physically tested with:

- Kindle Paperwhite 1
- Firmware 5.6.1.1
- KUAL
- FBInk
- Wi-Fi weather updates
- Hourly RTC suspend/wake cycles

## Current status

PaperCast is a public beta release. The current known-good build is **v0.9.0**.

It includes Hourly, Dayparts, and four-day forecast views. Precipitation probability and precipitation amount are shown in the current conditions and forecast views where corresponding Open-Meteo data is available.

## Installation

PaperCast currently requires a jailbroken Kindle with KUAL installed. The extension uses the existing `KindleDash/` runtime directory name for compatibility with tested devices and hard-coded runtime paths.

Public installation instructions and packaging cleanup are still in progress. Do not rename the installed extension directory unless the runtime paths are updated accordingly.

## Configuration

The current development configuration is:

```conf
LOCATION="Brussels"
LATITUDE="50.87002"
LONGITUDE="4.40824"
TIMEZONE="Europe/Brussels"
```

These coordinates represent the Evere development location while the visible dashboard label remains Brussels.

User-friendly city-only automatic location setup is planned. For now, changing location requires editing the configuration values directly.

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
