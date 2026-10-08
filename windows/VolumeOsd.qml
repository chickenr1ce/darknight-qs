pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.components
import qs.config
import qs.services

// Transient volume readout, raised by PipeWire property changes from any source
// (bar wheel, media keys, wpctl, pavucontrol) rather than the volume IPC, so it
// never depends on a caller going through this shell.
//
// Click-through: an empty mask Region and a hidden window mean it never
// intercepts input. The screen is captured when it goes hidden -> shown and
// held while up, so a focus change mid-display does not move it.

// qmllint disable uncreatable-type
PanelWindow {
    id: root

    readonly property var audioNode: AudioService.defaultSink ? (AudioService.defaultSink.audio ?? null) : null
    readonly property bool audioMuted: root.audioNode !== null && root.audioNode.muted
    readonly property string volumeGlyph: root.audioNode === null ? Icons.volumeOff : (root.audioNode.muted ? Icons.volumeMute : Icons.volumeHigh)
    readonly property string volumePercentText: AudioService.percentText(root.audioNode ? root.audioNode.volume : 0)
    readonly property real volumeFraction: AudioService.volumeFraction(root.audioNode ? root.audioNode.volume : 0)

    property bool shown: false
    property bool fading: false
    property bool armed: false

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.shown || root.fading

    anchors {
        bottom: true
    }

    margins {
        bottom: Globals.osdBottomMargin
    }

    implicitWidth: Globals.osdWidth
    implicitHeight: Globals.osdHeight

    mask: Region {}

    onAudioNodeChanged: root.arm()
    Component.onCompleted: root.arm()

    Connections {
        id: idOsdAudioConnections

        target: AudioService.defaultSink ? AudioService.defaultSink.audio : null

        function onVolumesChanged(): void {
            root.handleAudioChange();
        }

        function onMutedChanged(): void {
            root.handleAudioChange();
        }
    }

    PwObjectTracker {
        id: idOsdSinkTracker

        objects: AudioService.defaultSink ? [AudioService.defaultSink] : []
    }

    Connections {
        id: idOsdSettingConnections

        target: AudioService

        function onOsdEnabledChanged(): void {
            if (AudioService.osdEnabled)
                return;
            root.shown = false;
            root.fading = false;
            idOsdHideTimer.stop();
        }
    }

    Timer {
        id: idOsdArmTimer

        interval: Globals.osdArmMs
        onTriggered: root.armed = true
    }

    Timer {
        id: idOsdHideTimer

        interval: Globals.osdHoldMs
        onTriggered: root.beginFade()
    }

    Card {
        id: idOsdCard

        anchors.fill: parent
        opacity: root.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Globals.reducedMotion ? 0 : Globals.toastMs
                easing.type: Easing.OutCubic
                onRunningChanged: {
                    if (!running && !root.shown)
                        root.fading = false;
                }
            }
        }

        RowLayout {
            id: idOsdRow

            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Globals.rowSpacing

            Icon {
                id: idOsdGlyph

                Layout.alignment: Qt.AlignVCenter

                text: root.volumeGlyph
                size: Globals.uiIconSize
                color: root.audioMuted ? Colors.textSecondary : Colors.accent
            }

            Rectangle {
                id: idOsdBar

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: Globals.osdBarHeight
                Layout.alignment: Qt.AlignVCenter

                radius: Globals.pillRadius
                color: Colors.border
                opacity: root.audioMuted ? 0.5 : 1

                Rectangle {
                    id: idOsdBarFill

                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }

                    width: parent.width * root.volumeFraction
                    radius: Globals.pillRadius
                    color: Colors.accent
                }
            }

            Text {
                id: idOsdPercentLabel

                Layout.minimumWidth: idOsdPercentMetrics.advanceWidth
                Layout.alignment: Qt.AlignVCenter

                horizontalAlignment: Text.AlignRight
                textFormat: Text.PlainText
                text: root.volumePercentText + "%"
                color: Colors.text

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiBodySize
                    weight: Font.DemiBold
                    features: ({ "tnum": 1 })
                }
            }
        }
    }

    TextMetrics {
        id: idOsdPercentMetrics

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiBodySize
            weight: Font.DemiBold
            features: ({ "tnum": 1 })
        }

        text: "150%"
    }

    function arm(): void {
        root.armed = false;
        idOsdArmTimer.restart();
    }

    function handleAudioChange(): void {
        if (!AudioService.osdEnabled)
            return;
        if (!root.armed)
            return;
        if (!root.shown) {
            if (!root.fading)
                root.screen = MonitorService.focusedScreen();
            root.fading = false;
            root.shown = true;
        }
        idOsdHideTimer.restart();
    }

    function beginFade(): void {
        root.shown = false;
        if (Globals.reducedMotion) {
            root.fading = false;
            return;
        }
        root.fading = true;
    }
}
