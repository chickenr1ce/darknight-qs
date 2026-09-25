import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.config
import qs.components

ModuleBox {
    id: root

    property string monitorName: ""
    property bool tooltipArmed: false
    visible: Globals.onPrimaryMonitor(root.monitorName)

    readonly property PwNode defaultSink: Pipewire.defaultAudioSink
    readonly property var sinks: [
        { match: "JadeAudio", label: "JadeAudio JIEZI" },
        { match: "AB13X", label: "AB13X Dongle" },
        { match: "Pebble", label: "Creative Pebble V3" }
    ]
    readonly property bool tooltipShown: root.isHovered && root.tooltipArmed
    readonly property int tooltipAnimMs: Globals.reducedMotion ? 0 : Globals.hoverMs
    readonly property string currentOutputName: {
        const raw = root.defaultSink ? (root.defaultSink.description ?? root.defaultSink.name ?? "") : "";
        if (raw === "")
            return qsTr("No output");
        const index = root.sinkIndexFor(raw);
        return index === -1 ? raw : root.sinks[index].label;
    }

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

    onIsHoveredChanged: {
        idAudioTooltipDelayTimer.stop();
        root.tooltipArmed = false;
        if (root.isHovered)
            idAudioTooltipDelayTimer.start();
    }

    onCurrentOutputNameChanged: idTipSwapAnimation.restart()

    // Cycle order matches waybar toggle_audio.sh; disconnected sinks are skipped so a click never lands on nothing.
    function sinkIndexFor(raw: string): int {
        for (let i = 0; i < root.sinks.length; i++) {
            if (raw.includes(root.sinks[i].match))
                return i;
        }
        return -1;
    }

    function cycleAudioSink(): void {
        if (!Pipewire.nodes || !Pipewire.nodes.values)
            return;
        const currentLabel = root.defaultSink ? (root.defaultSink.description ?? root.defaultSink.name ?? "") : "";
        const currentIndex = root.sinkIndexFor(currentLabel);
        for (let step = 1; step <= root.sinks.length; step++) {
            const nextSink = root.sinks[(currentIndex + step) % root.sinks.length];
            for (const node of Pipewire.nodes.values) {
                // Sources share names with their sinks (AB13X mono vs stereo), so only match real sinks.
                if (!node.isSink || node.isStream)
                    continue;
                const nodeLabel = node.description ?? node.name ?? "";
                if (nodeLabel.includes(nextSink.match)) {
                    if (!idAudioSetDefaultProcess.running) {
                        idAudioSetDefaultProcess.command = ["wpctl", "set-default", String(node.id)];
                        idAudioSetDefaultProcess.running = true;
                    }
                    if (!idAudioNotifyProcess.running) {
                        idAudioNotifyProcess.command = ["notify-send", "Audio Switched", `Output: ${nextSink.label}`];
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

        Layout.alignment: Qt.AlignCenter

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

        onTextChanged: idAudioLabelSwapAnimation.restart()
    }

    PwObjectTracker {
        id: idAudioSinkTracker

        objects: [root.defaultSink]
    }

    Timer {
        id: idAudioTooltipDelayTimer

        interval: Globals.tooltipDelayMs
        onTriggered: root.tooltipArmed = true
    }

    ParallelAnimation {
        id: idAudioLabelSwapAnimation

        NumberAnimation {
            target: idAudioLabel
            property: "opacity"
            from: 0
            to: 1
            duration: root.tooltipAnimMs
        }
        NumberAnimation {
            target: idAudioLabel
            property: "scale"
            from: 0.93
            to: 1
            duration: root.tooltipAnimMs
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: idTipSwapAnimation

        NumberAnimation {
            target: idAudioTooltipText
            property: "opacity"
            from: 0
            to: 1
            duration: root.tooltipAnimMs
        }
        NumberAnimation {
            target: idAudioTooltipSlider
            property: "y"
            from: 8
            to: 0
            duration: root.tooltipAnimMs
            easing.type: Easing.OutCubic
        }
    }

    PopupWindow {
        id: idAudioTooltip

        visible: root.tooltipShown
        implicitWidth: idAudioTooltipText.implicitWidth + 2 * Globals.pillHPadding
        implicitHeight: idAudioTooltipText.implicitHeight + 2 * Globals.pillVPadding
        color: "transparent"

        mask: Region {
            width: 0
            height: 0
        }

        anchor {
            item: root
            edges: Edges.Bottom | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            adjustment: PopupAdjustment.Slide
            rect {
                x: root.width / 2 - idAudioTooltip.implicitWidth / 2
                y: root.height + Globals.panelTopGap
                width: idAudioTooltip.implicitWidth
                height: 1
            }
        }

        Item {
            id: idAudioTooltipContent

            anchors.fill: parent
            opacity: root.tooltipShown ? 1 : 0

            transform: Translate {
                y: root.tooltipShown ? 0 : 4

                Behavior on y {
                    NumberAnimation {
                        duration: root.tooltipAnimMs
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: root.tooltipAnimMs
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                id: idAudioTooltipCard

                anchors.fill: parent
                radius: Globals.radius
                color: Colors.panel
                border.width: Globals.hairlineHeight
                border.color: Colors.panelBorder
            }

            Item {
                id: idAudioTooltipSlider

                width: parent.width
                height: parent.height

                Text {
                    id: idAudioTooltipText

                    anchors.centerIn: parent
                    text: root.currentOutputName
                    color: Colors.text

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                        weight: Font.DemiBold
                    }
                }
            }
        }
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
