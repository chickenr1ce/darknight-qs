pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "StateParsers.js" as StateParsers

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

    property alias cavaVisible: idPanelState.visible
    property alias anchorScreen: idPanelState.anchorScreen
    property alias anchorCenterX: idPanelState.anchorCenterX
    readonly property PanelState panelState: idPanelState

    onSensitivityChanged: {
        if (idSettingsState.loading || !idSettingsState.loaded)
            return;
        root.saveSettings();
        root.requestEngineRestart();
    }
    onAutoSensitivityChanged: {
        if (idSettingsState.loading || !idSettingsState.loaded)
            return;
        root.saveSettings();
        root.requestEngineRestart();
    }
    onBarCountChanged: {
        root.levels = root.flatLevels();
        if (idSettingsState.loading || !idSettingsState.loaded)
            return;
        root.saveSettings();
        root.requestEngineRestart();
    }
    onStyleModeChanged: {
        if (idSettingsState.loading || !idSettingsState.loaded)
            return;
        root.saveSettings();
    }
    onMaxHeightChanged: {
        if (idSettingsState.loading || !idSettingsState.loaded)
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

    StateFile {
        id: idSettingsState

        name: "cava-settings"
        createDir: true
        onParsed: text => root.applySettings(text)
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

    function applySettings(jsonText: string): void {
        const limits = {};
        limits["sensitivity"] = [root.minSensitivity, root.maxSensitivity, root.sensitivity];
        limits["barCount"] = [root.minBarCount, root.maxBarCount, root.barCount];
        limits["styleMode"] = [root.minStyleMode, root.maxStyleMode, root.styleMode];
        limits["maxHeight"] = [root.minMaxHeight, root.maxMaxHeight, root.maxHeight];
        const next = StateParsers.parseCavaSettings(jsonText, limits);
        if (next === null)
            return;
        const engineBefore = root.sensitivity !== next.sensitivity || root.autoSensitivity !== next.autoSensitivity || root.barCount !== next.barCount;
        root.sensitivity = next.sensitivity;
        root.autoSensitivity = next.autoSensitivity;
        root.barCount = next.barCount;
        root.styleMode = next.styleMode;
        root.maxHeight = next.maxHeight;
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
        idSettingsState.saveJson(payload);
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

    function toggleCavaAt(screen, centerX: real): void {
        idPanelState.toggleAt(screen, centerX)
    }

    function openCavaAt(screen, centerX: real): void {
        idPanelState.openAt(screen, centerX)
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
