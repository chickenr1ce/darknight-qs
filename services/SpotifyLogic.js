.pragma library

function parseResponse(text) {
    const out = { ok: false, error: "", message: "", devices: [], activeId: "" };
    let parsed = null;
    try {
        parsed = JSON.parse(text);
    } catch (e) {
        out.message = qsTr("Spotify backend returned invalid JSON");
        return out;
    }
    if (!parsed || typeof parsed !== "object") {
        out.message = qsTr("Spotify backend returned an unexpected response");
        return out;
    }
    out.ok = parsed.ok === true;
    out.error = parsed.error || "";
    out.message = parsed.message || "";
    out.activeId = parsed.activeId || "";
    out.devices = Array.isArray(parsed.devices) ? parsed.devices : [];
    return out;
}
