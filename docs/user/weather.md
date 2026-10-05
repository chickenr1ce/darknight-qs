# Weather block and city search

The dashboard weather block shows the selected city, current temperature,
condition glyph, rain probability, and the day high and low. It needs network
on poll but keeps the last good reading when offline.

## Source and polling

`services/WeatherService.qml` fetches
`https://api.open-meteo.com/v1/forecast` with `curl` (10s timeout). No API key
is needed. It polls every 30 minutes and refreshes when the dashboard opens
(`windows/DashboardCenter.qml`).

The block reads `temperature_2m` and `weather_code` from `current`, plus the
day high, low, and rain probability from `daily`. The WMO weather code maps to
one of six glyphs in `config/Icons.qml` (sunny, cloudy, fog, rainy, snowy,
storm).

## Stale and cache

The block marks itself stale when the last poll failed or the reading is older
than 60 minutes. The city label gains a "Stale" suffix; the last values stay
visible instead of blanking.

The last good payload is cached at
`${XDG_CACHE_HOME:-~/.cache}/quickshell/weather.json`. A cached reading for
the current coordinates loads at startup, so the block has content before the
first poll returns.

## City search

Default location is Berlin (52.52, 13.41). Change it in Settings, Weather
section: type a name, Search, then Select one of up to 5 matches.

Search queries `https://geocoding-api.open-meteo.com/v1/search` and keeps
name, region, country, latitude, and longitude per result. Selecting a result
writes `${XDG_STATE_HOME:-~/.local/state}/quickshell/weather-location` and
repolls at once. An invalid saved file is ignored and the current location
stays.

The settings search matches the `City` and `Location` labels registered in
`services/SettingsService.qml`.

## Verify without the UI

```fish
scripts/test-dashboard-data.sh
scripts/test-panel-logic.sh
```

Section 6 of `test-dashboard-data.sh` checks the Open-Meteo URL, the 30 and
60 minute intervals, the parser and formatter functions, and the
`weather.json` cache. `test-panel-logic.sh` checks the settings view binds
`WeatherService.locationName`, `searchLocations`, `selectLocation`, and
`locationResults`, and that the city persists to `weather-location`.
`tests/fixtures/open-meteo-forecast.json` is the sample payload.
