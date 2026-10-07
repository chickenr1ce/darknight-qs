.pragma library

function parseWeather(text) {
    let parsed = null;
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

function formatTemp(celsius) {
    const value = Number(celsius);
    if (isNaN(value))
        return "";
    return Math.round(value) + "°";
}

function formatPrecip(percent) {
    const value = Number(percent);
    if (isNaN(value) || value < 0)
        return "";
    return Math.round(Math.max(0, Math.min(100, value))) + "%";
}

function glyphKeyFor(code) {
    const c = Math.round(Number(code));
    if (c === 0 || c === 1)
        return "weatherSunny";
    if (c === 2 || c === 3)
        return "weatherCloudy";
    if (c === 45 || c === 48)
        return "weatherFog";
    if ((c >= 51 && c <= 57) || (c >= 61 && c <= 67) || (c >= 80 && c <= 82))
        return "weatherRainy";
    if ((c >= 71 && c <= 77) || c === 85 || c === 86)
        return "weatherSnowy";
    if (c >= 95 && c <= 99)
        return "weatherStorm";
    if (c < 0)
        return "weatherSunny";
    return "weatherCloudy";
}

function isStale(nowMs, fetchedAtMs, failed, staleAfterMs) {
    if (failed)
        return true;
    if (!(fetchedAtMs > 0))
        return false;
    return (nowMs - fetchedAtMs) > staleAfterMs;
}

function isValidLocation(entry) {
    if (!entry || typeof entry !== "object")
        return false;
    const name = String(entry.name || "").trim();
    const latitude = Number(entry.latitude);
    const longitude = Number(entry.longitude);
    if (name === "" || isNaN(latitude) || isNaN(longitude))
        return false;
    return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
}

function parseLocations(text) {
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
        if (!isValidLocation(entry))
            continue;
        const name = String(entry.name || "").trim();
        const region = String(entry.admin1 || "").trim();
        const country = String(entry.country || "").trim();
        const item = {};
        item["name"] = name;
        item["label"] = name + (region !== "" ? ", " + region : "") + (country !== "" ? " (" + country + ")" : "");
        item["latitude"] = Number(entry.latitude);
        item["longitude"] = Number(entry.longitude);
        out.push(item);
    }
    return out;
}
