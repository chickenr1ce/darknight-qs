import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.config
import qs.components

ModuleBox {
    id: root

    readonly property PwNode defaultSink: Pipewire.defaultAudioSink

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            openMixer();
        else
            cycleAudioSink();
    }

    onWheelMoved: wheel => {
        if (!root.defaultSink || !root.defaultSink.audio)
            return;

        const audio = root.defaultSink.audio;
        const currentPercent = Math.round(audio.volume * 100);

        if (wheel.angleDelta.y > 0) {
            const nextPercent = Math.min(100, Math.floor(currentPercent / 5) * 5 + 5);
            audio.volume = nextPercent / 100;
        } else if (wheel.angleDelta.y < 0) {
            const prevPercent = Math.max(0, Math.ceil(currentPercent / 5) * 5 - 5);
            audio.volume = prevPercent / 100;
        }
    }

    // Cycle order matches waybar toggle_audio.sh; disconnected sinks are skipped so a click never lands on nothing.
    function cycleAudioSink(): void {
        const sinkOrder = ["JadeAudio", "AB13X", "Pebble"];
        const sinkLabels = {
            "JadeAudio": "JadeAudio JIEZI",
            "AB13X": "AB13X Dongle",
            "Pebble": "Creative Pebble V3"
        };
        if (!Pipewire.nodes || !Pipewire.nodes.values)
            return;
        const currentLabel = root.defaultSink ? (root.defaultSink.description ?? root.defaultSink.name ?? "") : "";
        let currentIndex = -1;
        for (let i = 0; i < sinkOrder.length; i++) {
            if (currentLabel.includes(sinkOrder[i]))
                currentIndex = i;
        }
        for (let step = 1; step <= sinkOrder.length; step++) {
            const nextSinkName = sinkOrder[(currentIndex + step) % sinkOrder.length];
            for (const node of Pipewire.nodes.values) {
                // Sources share names with their sinks (AB13X mono vs stereo), so only match real sinks.
                if (!node.isSink || node.isStream)
                    continue;
                const nodeLabel = node.description ?? node.name ?? "";
                if (nodeLabel.includes(nextSinkName)) {
                    if (!idAudioSetDefaultProcess.running) {
                        idAudioSetDefaultProcess.command = ["wpctl", "set-default", String(node.id)];
                        idAudioSetDefaultProcess.running = true;
                    }
                    if (!idAudioNotifyProcess.running) {
                        idAudioNotifyProcess.command = ["notify-send", "Audio Switched", `Output: ${sinkLabels[nextSinkName]}`];
                        idAudioNotifyProcess.running = true;
                    }
                    return;
                }
            }
        }
    }

    function openMixer(): void {
        idAudioMixerProcess.command = ["pavucontrol"];
        idAudioMixerProcess.running = true;
    }

    Text {
        id: idAudioLabel

        color: Colors.lavender
        text: {
            if (!root.defaultSink || !root.defaultSink.audio)
                return "";
            const audio = root.defaultSink.audio;
            const volumePercent = isNaN(audio.volume) ? 0 : Math.round(audio.volume * 100);
            const icon = audio.muted ? " " : " ";
            return `${icon}${volumePercent}%`;
        }
        font {
            family: Globals.fontFamily
            pixelSize: Globals.fontPixelSize
            weight: Font.DemiBold
        }
    }

    PwObjectTracker {
        id: idAudioSinkTracker

        objects: [root.defaultSink]
    }

    Process {
        id: idAudioSetDefaultProcess
    }
    Process {
        id: idAudioNotifyProcess
    }
    Process {
        id: idAudioMixerProcess
    }
}
