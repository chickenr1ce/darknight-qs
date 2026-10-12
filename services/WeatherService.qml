pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "WeatherLogic.js" as WeatherLogic

Singleton {
    id: root

    property string locationName: "Berlin"
    property real latitude: 52.52
    property real longitude: 13.41
    readonly property int pollMs: 30 * 60 * 1000
    readonly property int staleAfterMs: 60 * 60 * 1000
    readonly property string city: root.locationName

    property string searchQuery: ""
    property var locationResults: []
    property bool locationSearched: false
    readonly property bool searchBusy: idGeocodeRun.running

    property real temperatureC: 0
    property int weatherCode: -1
    property real precipProb: -1
    property real highC: 0
    property real lowC: 0
    property double fetchedAtMs: 0
    property bool lastPollFailed: false
    property bool locationPollIssued: false
    property date now: new Date()

    readonly property bool hasData: root.fetchedAtMs > 0
    readonly property bool stale: root.isStale(root.now.getTime(), root.fetchedAtMs, root.lastPollFailed)
    readonly property string tempText: root.hasData ? root.formatTemp(root.temperatureC) : ""
    readonly property string precipText: root.hasData ? root.formatPrecip(root.precipProb) : ""
    readonly property string highText: root.hasData ? root.formatTemp(root.highC) : ""
    readonly property string lowText: root.hasData ? root.formatTemp(root.lowC) : ""
    readonly property string glyph: root.glyphFor(root.hasData ? root.weatherCode : -1)

    Timer {
        id: idWeatherTimer

        interval: root.pollMs
        running: true
        repeat: true
        onTriggered: root.repoll()
    }

    Timer {
        id: idNowTimer

        interval: 60000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Process {
        id: idWeatherProcess

        command: ["curl", "-sS", "--max-time", "10", root.requestUrl()]
        stdout: idWeatherCollector
        stderr: idWeatherErrorCollector
        onExited: code => {
            if (code === 0)
                root.applyPayload(idWeatherCollector.text);
            else {
                root.lastPollFailed = true;
                console.warn("weather fetch failed with exit " + code + ": " + idWeatherErrorCollector.text.trim());
            }
            idWeatherRun.finished(code === 0);
        }
    }

    CoalescedRun {
        id: idWeatherRun

        process: idWeatherProcess

        starter: () => {
            idWeatherProcess.running = true;
        }
    }

    StdioCollector {
        id: idWeatherCollector
    }

    StdioCollector {
        id: idWeatherErrorCollector
    }

    StateFile {
        id: idWeatherState

        name: "weather.json"
        inCache: true
        onParsed: text => root.applyCache(text)
    }

    Process {
        id: idGeocodeProcess

        command: ["curl", "-sS", "--max-time", "10", root.geocodeUrl(root.searchQuery)]
        stdout: idGeocodeCollector
        stderr: idGeocodeErrorCollector
        onExited: code => {
            if (code === 0)
                root.applyLocations(idGeocodeCollector.text);
            else
                console.warn("weather geocode failed with exit " + code + ": " + idGeocodeErrorCollector.text.trim());
            idGeocodeRun.finished(code === 0);
        }
    }

    CoalescedRun {
        id: idGeocodeRun

        process: idGeocodeProcess

        starter: () => {
            idGeocodeProcess.running = true;
        }
    }

    StdioCollector {
        id: idGeocodeCollector
    }

    StdioCollector {
        id: idGeocodeErrorCollector
    }

    StateFile {
        id: idLocationState

        name: "weather-location"
        createDir: true
        onParsed: text => root.applyLocation(text)
        onLoadedChanged: {
            if (idLocationState.loaded)
                Qt.callLater(root.bootPoll);
        }
    }

    function refresh(): void {
        root.repoll()
    }

    function repoll(): void {
        idWeatherRun.request();
    }

    // Boot fetches once. The saved-location parse already issues the fetch
    // when its city differs from the default, so the load-completion trigger
    // asks WeatherLogic whether it still owns the boot fetch.
    function bootPoll(): void {
        if (WeatherLogic.shouldBootPoll(root.locationPollIssued))
            root.repoll();
    }

    function requestUrl(): string {
        return "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude + "&longitude=" + root.longitude + "&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=1";
    }

    function applyPayload(text: string): void {
        const parsed = root.parseWeather(text);
        if (parsed === null) {
            root.lastPollFailed = true;
            return;
        }
        root.temperatureC = parsed.temperatureC;
        root.weatherCode = parsed.weatherCode;
        root.precipProb = parsed.precipProb;
        root.highC = parsed.highC;
        root.lowC = parsed.lowC;
        root.fetchedAtMs = Date.now();
        root.lastPollFailed = false;
        root.saveCache();
    }

    function applyCache(text: string): void {
        let parsed = null;
        try
        {
            parsed = JSON.parse(text);
        }
        catch (e)
        {
            return;
        }
        if (!parsed || typeof parsed !== "object")
            return;
        const fetched = Number(parsed.fetchedAtMs);
        const temperatureC = Number(parsed.temperatureC);
        const weatherCode = Math.round(Number(parsed.weatherCode));
        if (!(fetched > 0) || isNaN(temperatureC) || isNaN(weatherCode))
            return;
        if (!(Number(parsed.latitude) === root.latitude && Number(parsed.longitude) === root.longitude))
            return;
        root.temperatureC = temperatureC;
        root.weatherCode = weatherCode;
        const precip = Number(parsed.precipProb);
        root.precipProb = isNaN(precip) ? -1 : precip;
        const high = Number(parsed.highC);
        root.highC = isNaN(high) ? temperatureC : high;
        const low = Number(parsed.lowC);
        root.lowC = isNaN(low) ? temperatureC : low;
        root.fetchedAtMs = fetched;
    }

    function saveCache(): void {
        const payload = {};
        payload["fetchedAtMs"] = root.fetchedAtMs;
        payload["latitude"] = root.latitude;
        payload["longitude"] = root.longitude;
        payload["temperatureC"] = root.temperatureC;
        payload["weatherCode"] = root.weatherCode;
        payload["precipProb"] = root.precipProb;
        payload["highC"] = root.highC;
        payload["lowC"] = root.lowC;
        idWeatherState.saveJson(payload);
    }

    function geocodeUrl(query: string): string {
        return "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(query) + "&count=5&language=en&format=json";
    }

    function searchLocations(query: string): void {
        const q = query.trim();
        if (q === "")
            return;
        root.searchQuery = q;
        Qt.callLater(root.repollGeocode);
    }

    function repollGeocode(): void {
        idGeocodeRun.request();
    }

    function applyLocations(text: string): void {
        root.locationResults = root.parseLocations(text);
        root.locationSearched = true;
    }

    function parseLocations(text: string): var {
        return WeatherLogic.parseLocations(text);
    }

    function selectLocation(index: int): void {
        if (index < 0 || index >= root.locationResults.length)
            return;
        const entry = root.locationResults[index];
        if (!entry)
            return;
        root.locationName = entry.name;
        root.latitude = entry.latitude;
        root.longitude = entry.longitude;
        root.locationResults = [];
        root.locationSearched = false;
        root.saveLocation();
        root.repoll();
    }

    function applyLocation(text: string): void {
        let parsed = null;
        try
        {
            parsed = JSON.parse(text);
        }
        catch (e)
        {
            return;
        }
        if (!WeatherLogic.isValidLocation(parsed))
            return;
        const name = String(parsed.name || "").trim();
        const latitude = Number(parsed.latitude);
        const longitude = Number(parsed.longitude);
        if (name === root.locationName && latitude === root.latitude && longitude === root.longitude)
            return;
        root.locationName = name;
        root.latitude = latitude;
        root.longitude = longitude;
        root.locationPollIssued = true;
        root.repoll();
    }

    function saveLocation(): void {
        const payload = {};
        payload["name"] = root.locationName;
        payload["latitude"] = root.latitude;
        payload["longitude"] = root.longitude;
        idLocationState.saveJson(payload);
    }

    function parseWeather(text: string): var {
        return WeatherLogic.parseWeather(text);
    }

    function formatTemp(celsius: real): string {
        return WeatherLogic.formatTemp(celsius);
    }

    function formatPrecip(percent: real): string {
        return WeatherLogic.formatPrecip(percent);
    }

    function glyphFor(code: int): string {
        return Icons[WeatherLogic.glyphKeyFor(code)];
    }

    function isStale(nowMs: double, fetchedAtMs: double, failed: bool): bool {
        return WeatherLogic.isStale(nowMs, fetchedAtMs, failed, root.staleAfterMs);
    }
}
