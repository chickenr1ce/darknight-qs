pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Spotify Connect device state for the dashboard player block. The token and
// every Web API call live in scripts/spotify-connect.py; this singleton only
// owns the list the block renders and the poll that keeps it fresh while the
// dashboard is open. A missing token is a normal state, not an error.
Singleton {
    id: root

    readonly property string scriptPath: Quickshell.shellDir + "/scripts/spotify-connect.py"
    readonly property int pollMs: 10000

    property var devices: []
    property string activeDeviceId: ""
    property bool authMissing: false
    property string lastError: ""
    property string pendingDeviceId: ""
    property bool pollQueued: false

    readonly property bool hasDevices: root.devices.length > 0
    readonly property bool transferring: idTransferProcess.running

    Timer {
        id: idPollTimer

        interval: root.pollMs
        running: DashboardService.dashboardVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshDevices()
    }

    Process {
        id: idDevicesProcess

        command: ["python3", root.scriptPath, "devices"]
        stdout: StdioCollector { id: idDevicesCollector }
        onExited: code => root.applyDevicesResult(code, idDevicesCollector.text)
    }

    Process {
        id: idTransferProcess

        command: root.pendingDeviceId === "" ? [] : ["python3", root.scriptPath, "transfer", "--device-id", root.pendingDeviceId, "--play"]
        stdout: StdioCollector { id: idTransferCollector }
        onExited: code => root.applyTransferResult(code, idTransferCollector.text)
    }

    function refreshDevices(): void {
        if (idDevicesProcess.running) {
            root.pollQueued = true;
            return;
        }
        idDevicesProcess.running = true;
    }

    function transferTo(deviceId: string): void {
        if (deviceId === "" || idTransferProcess.running)
            return;
        root.pendingDeviceId = deviceId;
        idTransferProcess.running = true;
    }

    function applyDevicesResult(code: int, text: string): void {
        if (root.pollQueued) {
            root.pollQueued = false;
            idDevicesProcess.running = true;
        }
        const parsed = root.parseResponse(text);
        if (code !== 0 || !parsed.ok) {
            root.authMissing = parsed.error === "auth_missing";
            root.lastError = parsed.message !== "" ? parsed.message : qsTr("Spotify device list unavailable");
            if (root.authMissing) {
                root.devices = [];
                root.activeDeviceId = "";
            }
            return;
        }
        root.authMissing = false;
        root.lastError = "";
        root.devices = parsed.devices;
        root.activeDeviceId = parsed.activeId;
    }

    function applyTransferResult(code: int, text: string): void {
        root.pendingDeviceId = "";
        const parsed = root.parseResponse(text);
        if (code !== 0 || !parsed.ok) {
            root.authMissing = parsed.error === "auth_missing";
            root.lastError = parsed.message !== "" ? parsed.message : qsTr("Spotify device switch failed");
            console.warn("spotify: device switch failed: " + root.lastError);
            return;
        }
        root.refreshDevices();
    }

    function parseResponse(text: string): var {
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
}
