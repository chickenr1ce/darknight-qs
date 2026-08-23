import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.config
import qs.components

// Volume from the default PipeWire sink.
// Left-click cycles the three named sinks (replaces toggle_audio.sh).
// Right-click opens pavucontrol.
ModuleBox {
    id: root

    property var defaultSink: Pipewire.defaultAudioSink

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

    function cycleAudioSink(): void {
        const sinkOrder = ["JadeAudio", "AB13X", "Pebble"];
        const currentLabel = root.defaultSink ? (root.defaultSink.description ?? root.defaultSink.name ?? "") : "";
        let currentIndex = -1;
        for (let i = 0; i < sinkOrder.length; i++) {
            if (currentLabel.includes(sinkOrder[i]))
                currentIndex = i;
        }
        const nextSinkName = sinkOrder[(currentIndex + 1) % sinkOrder.length];
        for (const node of Pipewire.nodes.values) {
            const nodeLabel = node.description ?? node.name ?? "";
            if (nodeLabel.includes(nextSinkName)) {
                idAudioSetDefaultProcess.command = ["wpctl", "set-default", String(node.id)];
                idAudioSetDefaultProcess.running = true;
                return;
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
        font.family: Globals.fontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold
        text: {
            if (!root.defaultSink || !root.defaultSink.audio)
                return "";
            const audio = root.defaultSink.audio;
            const volumePercent = isNaN(audio.volume) ? 0 : Math.round(audio.volume * 100);
            const icon = audio.muted ? " " : " ";
            return `${icon}${volumePercent}%`;
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
        id: idAudioMixerProcess
    }
}
