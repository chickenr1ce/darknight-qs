import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../config"
import "../components"

// Volume from the default PipeWire sink.
// Left-click cycles the three named sinks (replaces toggle_audio.sh).
// Right-click opens pavucontrol.
ModuleBox {
    id: root

    property var defaultSink: Pipewire.defaultAudioSink

    Text {
        id: idAudioLabel

        color: Colors.lavender
        font.family: Globals.fontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold
        text: {
            if (!root.defaultSink)
                return "";
            const volumePercent = Math.round((root.defaultSink.volume ?? 1) * 100);
            const icon = root.defaultSink.muted ? " " : " ";
            return `${icon}${volumePercent}%`;
        }
    }

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            openMixer();
        else
            cycleAudioSink();
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
        for (const node of Pipewire.nodes) {
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

    Process {
        id: idAudioSetDefaultProcess
    }
    Process {
        id: idAudioMixerProcess
    }
}
