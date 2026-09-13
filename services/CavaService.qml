pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Single cava analyser for every bar instance; modules bind levels and stay presentation-only.
Singleton {
    id: root

    readonly property int barCount: 14
    readonly property int asciiMax: 1000

    property var levels: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property double lastFrameMs: 0

    Process {
        id: idCavaProcess

        // Missing cava exits clean so the restart timer never spins.
        // QString truncates binary nulls, so ascii keeps every frame parseable.
        // Sensitivity 750 fills the bars at typical listening volume; retune if peaks clip.
        // Waybar 0.77 noise maps to cava's 0-100 scale.
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 || exit 0; cfg=\"${XDG_RUNTIME_DIR:-/tmp}/quickshell-cava.conf\"; printf '%s\\n' '[general]' 'framerate = 30' 'bars = 14' 'sensitivity = 1200' 'autosens = 0' 'lower_cutoff_freq = 50' 'higher_cutoff_freq = 10000' '' '[input]' 'method = pipewire' 'source = auto' '' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 1000' 'bar_delimiter = 59' 'frame_delimiter = 10' 'channels = mono' 'mono_option = average' '' '[smoothing]' 'noise_reduction = 77' > \"$cfg\"; exec cava -p \"$cfg\""]
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

    // A dead process would freeze the last peak; fall back to flat instead.
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
