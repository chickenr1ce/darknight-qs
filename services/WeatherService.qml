pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

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
    property bool geocodeQueued: false
    readonly property bool searchBusy: idGeocodeProcess.running

    property real temperatureC: 0
    property int weatherCode: -1
    property real precipProb: -1
    property real highC: 0
    property real lowC: 0
    property double fetchedAtMs: 0
    property bool lastPollFailed: false
    property bool pollQueued: false
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
        triggeredOnStart: true
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
            if (root.pollQueued) {
                root.pollQueued = false;
                idWeatherProcess.running = true;
            }
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
            if (root.geocodeQueued) {
                root.geocodeQueued = false;
                idGeocodeProcess.running = true;
            }
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
    }

    function refresh(): void {
        root.repoll()
    }

    function repoll(): void {
        if (idWeatherProcess.running)
            root.pollQueued = true;
        else
            idWeatherProcess.running = true;
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
        idWeatherState.save(JSON.stringify(payload) + "\n");
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
        if (idGeocodeProcess.running)
            root.geocodeQueued = true;
        else
            idGeocodeProcess.running = true;
    }

    function applyLocations(text: string): void {
        root.locationResults = root.parseLocations(text);
        root.locationSearched = true;
    }

    function parseLocations(text: string): var {
        let parsed = null;
        try
        {
            parsed = JSON.parse(text);
        }
        catch (e)
        {
            return [];
        }
        if (!parsed || typeof parsed !== "object" || !Array.isArray(parsed.results))
            return [];
        const out = [];
        for (let i = 0; i < parsed.results.length && out.length < 5; i++) {
            const entry = parsed.results[i];
            if (!entry || typeof entry !== "object")
                continue;
            const name = String(entry.name || "").trim();
            const latitude = Number(entry.latitude);
            const longitude = Number(entry.longitude);
            if (name === "" || isNaN(latitude) || isNaN(longitude))
                continue;
            if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180)
                continue;
            const region = String(entry.admin1 || "").trim();
            const country = String(entry.country || "").trim();
            const item = {};
            item["name"] = name;
            item["label"] = name + (region !== "" ? ", " + region : "") + (country !== "" ? " (" + country + ")" : "");
            item["latitude"] = latitude;
            item["longitude"] = longitude;
            out.push(item);
        }
        return out;
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
        if (!parsed || typeof parsed !== "object")
            return;
        const name = String(parsed.name || "").trim();
        const latitude = Number(parsed.latitude);
        const longitude = Number(parsed.longitude);
        if (name === "" || isNaN(latitude) || isNaN(longitude))
            return;
        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180)
            return;
        if (name === root.locationName && latitude === root.latitude && longitude === root.longitude)
            return;
        root.locationName = name;
        root.latitude = latitude;
        root.longitude = longitude;
        root.repoll();
    }

    function saveLocation(): void {
        const payload = {};
        payload["name"] = root.locationName;
        payload["latitude"] = root.latitude;
        payload["longitude"] = root.longitude;
        idLocationState.save(JSON.stringify(payload) + "\n");
    }

    function parseWeather(text: string): var {        let parsed = null;
        try
        {
            parsed = JSON.parse(text);
        }
        catch (e)
        {
            return null;
        }
        if (!parsed || typeof parsed !== "object")
            return null;
        const current = parsed.current;
        if (!current || typeof current !== "object")
            return null;
        const temperatureC = Number(current.temperature_2m);
        const weatherCode = Math.round(Number(current.weather_code));
        if (isNaN(temperatureC) || isNaN(weatherCode))
            return null;
        let highC = temperatureC;
        let lowC = temperatureC;
        let precipProb = -1;
        const daily = parsed.daily;
        if (daily && typeof daily === "object") {
            if (Array.isArray(daily.temperature_2m_max) && daily.temperature_2m_max.length > 0) {
                const high = Number(daily.temperature_2m_max[0]);
                if (!isNaN(high))
                    highC = high;
            }
            if (Array.isArray(daily.temperature_2m_min) && daily.temperature_2m_min.length > 0) {
                const low = Number(daily.temperature_2m_min[0]);
                if (!isNaN(low))
                    lowC = low;
            }
            if (Array.isArray(daily.precipitation_probability_max) && daily.precipitation_probability_max.length > 0) {
                const precip = Number(daily.precipitation_probability_max[0]);
                if (!isNaN(precip))
                    precipProb = precip;
            }
        }
        const out = {};
        out["temperatureC"] = temperatureC;
        out["weatherCode"] = weatherCode;
        out["precipProb"] = precipProb;
        out["highC"] = highC;
        out["lowC"] = lowC;
        return out;
    }

    function formatTemp(celsius: real): string {
        const value = Number(celsius);
        if (isNaN(value))
            return "";
        return Math.round(value) + "°";
    }

    function formatPrecip(percent: real): string {
        const value = Number(percent);
        if (isNaN(value) || value < 0)
            return "";
        return Math.round(Math.max(0, Math.min(100, value))) + "%";
    }

    function glyphFor(code: int): string {
        const c = Math.round(Number(code));
        if (c === 0 || c === 1)
            return Icons.weatherSunny;
        if (c === 2 || c === 3)
            return Icons.weatherCloudy;
        if (c === 45 || c === 48)
            return Icons.weatherFog;
        if ((c >= 51 && c <= 57) || (c >= 61 && c <= 67) || (c >= 80 && c <= 82))
            return Icons.weatherRainy;
        if ((c >= 71 && c <= 77) || c === 85 || c === 86)
            return Icons.weatherSnowy;
        if (c >= 95 && c <= 99)
            return Icons.weatherStorm;
        if (c < 0)
            return Icons.weatherSunny;
        return Icons.weatherCloudy;
    }

    function isStale(nowMs: double, fetchedAtMs: double, failed: bool): bool {
        if (failed)
            return true;
        if (!(fetchedAtMs > 0))
            return false;
        return (nowMs - fetchedAtMs) > root.staleAfterMs;
    }
}
