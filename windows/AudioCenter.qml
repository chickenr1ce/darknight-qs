pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.components
import qs.config
import qs.dev
import qs.services

PanelShell {
    id: root

    readonly property string defaultSinkKey: AudioService.defaultSink ? AudioService.keyFor(AudioService.defaultSink) : ""
    readonly property string defaultSourceKey: AudioService.defaultSource ? AudioService.keyFor(AudioService.defaultSource) : ""
    readonly property var sinkEntries: AudioService.sinks
    readonly property var sourceEntries: AudioService.sources
    readonly property string inputUsageText: {
        const names = AudioService.captureAppNames(idInputLinks.linkGroups);
        return names.length === 0 ? "" : qsTr("In use by %1").arg(names.join(", "));
    }
    readonly property string streamCountText: {
        const count = AudioService.appStreams.length;
        if (count === 0)
            return "";
        return count === 1 ? qsTr("1 stream") : qsTr("%1 streams").arg(count);
    }
    readonly property int appsFixedHeight: {
        let total = 0;
        let count = 0;
        const children = idAudioBody.children;
        for (let i = 0; i < children.length; i++) {
            const child = children[i];
            if (child === idAppsSlot || child.visible === false)
                continue;
            total += child.implicitHeight;
            count++;
        }
        return total + count * idAudioBody.spacing;
    }
    readonly property int appsScrollMax: Math.max(0,
        Globals.centerMaxHeight - 2 * Globals.panelPadding
        - idAudioHeader.implicitHeight - Globals.spacing - root.appsFixedHeight)

    panel: AudioService.panelState
    geometryName: "audio.panel"
    panelWidth: Globals.centerWidth

    Component.onCompleted: DevGeometry.register("audio.card", idAudioBody)
    Component.onDestruction: DevGeometry.unregister("audio.card")

    PanelHeader {
        id: idAudioHeader

        title: qsTr("Sound")
        showBadge: false

        IconButton {
            id: idOpenMixerButton

            Layout.alignment: Qt.AlignVCenter

            glyph: Icons.openExternal
            accessibleName: qsTr("Open pavucontrol")
            onClicked: {
                Quickshell.execDetached(["pavucontrol"]);
                AudioService.panelState.closeFromOutside();
            }
        }
    }

    ColumnLayout {
        id: idAudioBody

        Layout.fillWidth: true

        spacing: Globals.listSpacing

        SectionLabel {
            id: idOutputLabel

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            text: qsTr("Output")
        }

        Dropdown {
            id: idOutputDropdown

            Layout.fillWidth: true

            options: root.sinkEntries.map(entry => entry.label)
            currentIndex: AudioService.indexOfKey(root.sinkEntries, root.defaultSinkKey)
            accessibleName: qsTr("Output device")
            onSelected: index => {
                const entry = root.sinkEntries[index];
                if (entry)
                    AudioService.setDefaultSink(entry.node);
            }
        }

        VolumeControl {
            id: idOutputVolume

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            node: AudioService.defaultSink
            trailingMute: true
            accessibleName: qsTr("Output volume")
        }

        SectionDivider {
            id: idInputSeparator

            Layout.fillWidth: true
        }

        RowLayout {
            id: idInputHeader

            Layout.fillWidth: true

            spacing: Globals.rowSpacing

            SectionLabel {
                id: idInputLabel

                Layout.fillWidth: true
                Layout.minimumWidth: 0

                text: qsTr("Input")
            }

            Text {
                id: idInputUsage

                Layout.maximumWidth: Math.max(0, idInputHeader.width - idInputLabel.implicitWidth - Globals.rowSpacing)
                Layout.preferredHeight: idInputUsageMetrics.height
                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: root.inputUsageText
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                }
            }
        }

        Dropdown {
            id: idInputDropdown

            Layout.fillWidth: true

            options: root.sourceEntries.map(entry => entry.label)
            currentIndex: AudioService.indexOfKey(root.sourceEntries, root.defaultSourceKey)
            accessibleName: qsTr("Input device")
            onSelected: index => {
                const entry = root.sourceEntries[index];
                if (entry)
                    AudioService.setDefaultSource(entry.node);
            }
        }

        VolumeControl {
            id: idInputVolume

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            node: AudioService.defaultSource
            micGlyphs: true
            trailingMute: true
            accessibleName: qsTr("Input volume")
        }

        Item {
            id: idInputMeter

            Layout.fillWidth: true

            implicitHeight: Globals.meterHeight

            Rectangle {
                id: idInputMeterTrack

                x: idInputVolume.x + idInputVolume.trackX
                y: 0
                width: idInputVolume.trackWidth
                height: Globals.meterHeight

                radius: Globals.pillRadius
                color: Colors.border

                Rectangle {
                    id: idInputMeterFill

                    width: idInputMeterTrack.width * (Number.isFinite(idInputPeak.peak) ? Math.min(1, Math.max(0, idInputPeak.peak)) : 0)
                    height: parent.height

                    radius: parent.radius
                    color: Colors.accent
                }
            }
        }

        SectionDivider {
            id: idAppsSeparator

            Layout.fillWidth: true
        }

        RowLayout {
            id: idAppsHeader

            Layout.fillWidth: true

            spacing: Globals.rowSpacing

            SectionLabel {
                id: idAppsLabel

                Layout.fillWidth: true
                Layout.minimumWidth: 0

                text: qsTr("Apps")
            }

            Text {
                id: idAppsCount

                Layout.preferredHeight: idAppsCountMetrics.height
                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                text: root.streamCountText
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                }
            }
        }

        Item {
            id: idAppsSlot

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(idAppsColumn.implicitHeight, root.appsScrollMax)
            Layout.maximumHeight: root.appsScrollMax

            Flickable {
                id: idAppsFlickable

                anchors.fill: parent

                contentWidth: width
                contentHeight: idAppsColumn.implicitHeight
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: ScrollBar { id: idAppsScrollBar }

                Column {
                    id: idAppsColumn

                    width: idAppsFlickable.width - Globals.scrollbarWidth

                    spacing: Globals.listSpacing

                    Repeater {
                        model: AudioService.appStreams

                        RowLayout {
                            id: idStreamRow

                            required property var modelData

                            readonly property var streamNode: idStreamRow.modelData
                            readonly property var streamAudio: idStreamRow.streamNode ? (idStreamRow.streamNode.audio ?? null) : null
                            readonly property bool streamMuted: Boolean(idStreamRow.streamAudio) && idStreamRow.streamAudio.muted

                            width: idAppsColumn.width
                            spacing: Globals.rowSpacing

                            AppIcon {
                                id: idStreamIcon

                                Layout.alignment: Qt.AlignVCenter

                                size: Globals.mixerIconSize
                                name: idStreamRow.streamNode ? AudioService.appName(idStreamRow.streamNode) : ""
                                source: idStreamRow.streamNode ? AppService.iconForName(AudioService.appIconName(idStreamRow.streamNode)) : ""
                            }

                            ColumnLayout {
                                id: idStreamLabels

                                Layout.preferredWidth: Globals.mixerLabelWidth
                                Layout.alignment: Qt.AlignVCenter

                                spacing: 0

                                Text {
                                    id: idStreamName

                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0

                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    text: idStreamRow.streamNode ? AudioService.appName(idStreamRow.streamNode) : ""
                                    color: idStreamRow.streamMuted ? Colors.textFaint : Colors.text

                                    font {
                                        family: Globals.uiFontFamily
                                        pixelSize: Globals.uiBodySize
                                    }
                                }

                                Text {
                                    id: idStreamTitle

                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredHeight: idStreamTitleMetrics.height

                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    text: idStreamRow.streamNode ? AudioService.streamTitle(idStreamRow.streamNode) : ""
                                    color: Colors.textFaint

                                    font {
                                        family: Globals.uiFontFamily
                                        pixelSize: Globals.uiCaptionSize
                                    }
                                }
                            }

                            VolumeControl {
                                id: idStreamVolume

                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.alignment: Qt.AlignVCenter

                                node: idStreamRow.streamNode
                                trailingMute: true
                                dimmed: idStreamRow.streamMuted
                                accessibleName: idStreamRow.streamNode ? AudioService.appName(idStreamRow.streamNode) : ""
                            }
                        }
                    }

                    Text {
                        id: idAppsEmpty

                        width: idAppsColumn.width

                        visible: AudioService.appStreams.length === 0
                        textFormat: Text.PlainText
                        text: qsTr("Nothing is playing")
                        color: Colors.textSubtle

                        font {
                            family: Globals.uiFontFamily
                            pixelSize: Globals.uiBodySize
                        }
                    }
                }
            }

            SmoothWheel {
                id: idAppsSmoothWheel

                flickable: idAppsFlickable
            }
        }
    }

    PwNodeLinkTracker {
        id: idInputLinks

        // Quickshell 0.3.1 PwNodeLinkTracker::updateLinks returns instead of
        // continuing on a monitor target, so a briefly stale caption is accepted.
        node: AudioService.defaultSource
    }

    PwNodePeakMonitor {
        id: idInputPeak

        node: AudioService.defaultSource
        enabled: AudioService.panelState.visible
    }

    TextMetrics {
        id: idInputUsageMetrics

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }

        text: qsTr("In use by")
    }

    TextMetrics {
        id: idStreamTitleMetrics

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }

        text: "Ag"
    }

    TextMetrics {
        id: idAppsCountMetrics

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }

        text: qsTr("1 stream")
    }
}
