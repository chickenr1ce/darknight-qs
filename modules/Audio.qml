import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

ModuleBox {
    id: root

    property string monitorName: ""
    property bool tooltipArmed: false
    visible: BarVisibilityService.isVisible("audio") && Globals.onPrimaryMonitor(root.monitorName)

    readonly property PwNode defaultSink: Pipewire.defaultAudioSink
    readonly property bool tooltipShown: root.isHovered && root.tooltipArmed
    readonly property int tooltipAnimMs: Globals.reducedMotion ? 0 : Globals.hoverMs
    readonly property string currentOutputName: root.defaultSink ? AudioService.rawLabelFor(root.defaultSink) : qsTr("No output")

    readonly property var audioNode: root.defaultSink ? (root.defaultSink.audio ?? null) : null
    readonly property string volumeGlyph: root.audioNode === null ? Icons.volumeOff : (root.audioNode.muted ? Icons.volumeMute : Icons.volumeHigh)
    readonly property string volumeText: root.audioNode === null ? "" : `${isNaN(root.audioNode.volume) ? 0 : Math.round(root.audioNode.volume * 100)}%`

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
    onVolumeTextChanged: idAudioLabelSwapAnimation.restart()

    function cycleAudioSink(): void {
        const sinks = AudioService.sinks;
        if (sinks.length === 0)
            return;
        let currentIndex = -1;
        for (let i = 0; i < sinks.length; i++) {
            if (AudioService.isDefaultNode(sinks[i].node)) {
                currentIndex = i;
                break;
            }
        }
        const next = sinks[(currentIndex + 1) % sinks.length];
        if (AudioService.isDefaultNode(next.node))
            return;
        if (!idAudioSetDefaultProcess.running) {
            idAudioSetDefaultProcess.command = ["wpctl", "set-default", String(next.node.id)];
            idAudioSetDefaultProcess.running = true;
        }
        if (!idAudioNotifyProcess.running) {
            idAudioNotifyProcess.command = ["notify-send", "Audio Switched", `Output: ${next.label}`];
            idAudioNotifyProcess.running = true;
        }
    }

    function openMixer(): void {
        idAudioMixerProcess.command = ["pavucontrol"];
        idAudioMixerProcess.running = true;
    }

    Row {
        id: idAudioLabel

        Layout.alignment: Qt.AlignCenter
        spacing: 4

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.volumeGlyph
            size: Globals.fontPixelSize
            color: Colors.accent
        }

        Text {
            id: idAudioLabelText

            anchors.verticalCenter: parent.verticalCenter

            textFormat: Text.PlainText
            text: root.volumeText
            color: Colors.accent

            font {
                family: Globals.fontFamily
                pixelSize: Globals.fontPixelSize
                weight: Font.DemiBold
            }
        }
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
