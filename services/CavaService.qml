pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int sensitivity: 1200
    property bool autoSensitivity: false
    property int barCount: 14
    property int styleMode: 0
    property int maxHeight: 20

    readonly property int asciiMax: 1000
    readonly property int minBarCount: 4
    readonly property int maxBarCount: 32
    readonly property int minSensitivity: 100
    readonly property int maxSensitivity: 5000
    readonly property int minStyleMode: 0
    readonly property int maxStyleMode: 5
    readonly property int minMaxHeight: 6
    readonly property int maxMaxHeight: 20
    readonly property var styleNames: ["Bars", "Mirrored", "Wave", "Wave Blocks", "Ribbon", "Ribbon Blocks"]

    property var levels: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property double lastFrameMs: 0
    property bool applyingSettings: false

    property alias cavaVisible: idPanelState.visible
    property alias cavaLastOutsideCloseAt: idPanelState.lastOutsideCloseAt
    property alias anchorScreen: idPanelState.anchorScreen
    property alias anchorCenterX: idPanelState.anchorCenterX

    readonly property string stateDirPath: root.stateBase() + "/quickshell"
    readonly property string settingsPath: root.stateFile("cava-settings")

    onSensitivityChanged: {
        if (root.applyingSettings)
            return;
        root.saveSettings();
        root.requestEngineRestart();
    }
    onAutoSensitivityChanged: {
        if (root.applyingSettings)
            return;
        root.saveSettings();
        root.requestEngineRestart();
    }
    onBarCountChanged: {
        root.levels = root.flatLevels();
        if (root.applyingSettings)
            return;
        root.saveSettings();
        root.requestEngineRestart();
    }
    onStyleModeChanged: {
        if (root.applyingSettings)
            return;
        root.saveSettings();
    }
    onMaxHeightChanged: {
        if (root.applyingSettings)
            return;
        root.saveSettings();
    }

    Process {
        id: idCavaProcess

        // Missing cava exits clean so the restart timer never spins.
        // QString truncates binary nulls, so ascii keeps every frame parseable.
        // Sensitivity 1200 fills the bars at typical listening volume; retune if peaks clip.
        // Waybar 0.77 noise maps to cava's 0-100 scale.
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 || exit 0; cfg=\"${XDG_RUNTIME_DIR:-/tmp}/quickshell-cava.conf\"; printf '%s\\n' '[general]' 'framerate = 30' 'bars = " + root.barCount + "' 'sensitivity = " + root.sensitivity + "' 'autosens = " + (root.autoSensitivity ? 1 : 0) + "' 'lower_cutoff_freq = 50' 'higher_cutoff_freq = 10000' '' '[input]' 'method = pipewire' 'source = auto' '' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 1000' 'bar_delimiter = 59' 'frame_delimiter = 10' 'channels = mono' 'mono_option = average' '' '[smoothing]' 'noise_reduction = 77' > \"$cfg\"; exec cava -p \"$cfg\""]
        running: true

        stdout: SplitParser {
            id: idCavaSplitter

            splitMarker: "\n"
            onRead: data => root.handleFrame(data)
        }

        onExited: exitCode => {
            if (exitCode !== 0 && !idCavaRestartTimer.running)
                idCavaRestartTimer.restart();
        }
    }

    Timer {
        id: idCavaRestartTimer

        interval: 1500
        onTriggered: {
            if (!idCavaProcess.running)
                idCavaProcess.running = true;
        }
    }

    Timer {
        id: idCavaEngineRestartTimer

        interval: 250
        onTriggered: root.restartAnalyser()
    }

    Timer {
        id: idCavaSilenceTimer

        interval: 300
        running: true
        repeat: true
        onTriggered: {
            if (Date.now() - root.lastFrameMs > 600)
                root.levels = root.flatLevels();
        }
    }

    Process {
        id: idCavaDirProcess

        command: ["mkdir", "-p", root.stateDirPath]
        running: true
        onExited: idCavaSettingsFile.reload()
    }

    FileView {
        id: idCavaSettingsFile

        path: "file://" + root.settingsPath
        printErrors: false
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: root.applySettings(this.text())
    }

    function stateBase(): string {
        return Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state");
    }

    function stateFile(name: string): string {
        return root.stateDirPath + "/" + name;
    }

    function requestEngineRestart(): void {
        idCavaEngineRestartTimer.restart();
    }

    function restartAnalyser(): void {
        if (idCavaProcess.running)
            idCavaProcess.running = false;
        Qt.callLater(() => {
            if (!idCavaProcess.running)
                idCavaProcess.running = true;
        });
    }

    function parseSettings(jsonText: string): var {
        let parsed = null;
        try
        {
            parsed = JSON.parse(jsonText);
        }
        catch (e)
        {
            return null;
        }
        if (!parsed || typeof parsed !== "object")
            return null;
        const clampInt = (value, lo, hi, fallback) => {
            const n = Math.round(Number(value));
            if (isNaN(n))
                return fallback;
            return Math.max(lo, Math.min(hi, n));
        };
        const out = {};
        out["sensitivity"] = clampInt(parsed.sensitivity, root.minSensitivity, root.maxSensitivity, root.sensitivity);
        out["autoSensitivity"] = parsed.autoSensitivity === true || parsed.autoSensitivity === 1;
        out["barCount"] = clampInt(parsed.barCount, root.minBarCount, root.maxBarCount, root.barCount);
        out["styleMode"] = clampInt(parsed.styleMode, root.minStyleMode, root.maxStyleMode, root.styleMode);
        out["maxHeight"] = clampInt(parsed.maxHeight, root.minMaxHeight, root.maxMaxHeight, root.maxHeight);
        return out;
    }

    function applySettings(jsonText: string): void {
        const next = root.parseSettings(jsonText);
        if (next === null)
            return;
        const engineBefore = root.sensitivity !== next.sensitivity || root.autoSensitivity !== next.autoSensitivity || root.barCount !== next.barCount;
        root.applyingSettings = true;
        root.sensitivity = next.sensitivity;
        root.autoSensitivity = next.autoSensitivity;
        root.barCount = next.barCount;
        root.styleMode = next.styleMode;
        root.maxHeight = next.maxHeight;
        root.applyingSettings = false;
        if (root.levels.length !== root.barCount)
            root.levels = root.flatLevels();
        if (engineBefore)
            root.requestEngineRestart();
    }

    function saveSettings(): void {
        const payload = {};
        payload["sensitivity"] = root.sensitivity;
        payload["autoSensitivity"] = root.autoSensitivity;
        payload["barCount"] = root.barCount;
        payload["styleMode"] = root.styleMode;
        payload["maxHeight"] = root.maxHeight;
        idCavaSettingsFile.setText(JSON.stringify(payload) + "\n");
    }

    function setStyleMode(mode: int): void {
        let n = Math.round(mode);
        if (isNaN(n))
            return;
        n = Math.max(root.minStyleMode, Math.min(root.maxStyleMode, n));
        if (n !== root.styleMode)
            root.styleMode = n;
    }

    function cycleStyle(delta: int): void {
        const count = root.maxStyleMode - root.minStyleMode + 1;
        const offset = ((root.styleMode - root.minStyleMode + delta) % count + count) % count;
        root.styleMode = root.minStyleMode + offset;
    }

    PanelState {
        id: idPanelState
    }

    function toggleCava(): void {
        idPanelState.toggle()
    }

    function toggleCavaAt(screen, centerX: real): void {
        idPanelState.toggleAt(screen, centerX)
    }

    function closeCavaFromOutside(): void {
        idPanelState.closeFromOutside()
    }

    function flatLevels(): var {
        const flat = [];
        for (let i = 0; i < root.barCount; i++)
            flat.push(0);
        return flat;
    }

    function handleFrame(data: string): void {
        const parts = data.trim().split(";");
        if (parts.length < root.barCount)
            return;
        const next = [];
        for (let i = 0; i < root.barCount; i++) {
            const raw = parseInt(parts[i], 10);
            next.push(isNaN(raw) ? 0 : Math.max(0, Math.min(1, raw / root.asciiMax)));
        }
        root.levels = next;
        root.lastFrameMs = Date.now();
    }
}
