pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.components
import qs.config
import qs.services

Card {
    id: root

    readonly property MprisPlayer player: MprisPlayers.activePlayer
    readonly property bool hasPlayer: root.player !== null
    readonly property bool playing: root.hasPlayer && root.player.playbackState === MprisPlaybackState.Playing
    readonly property int loopState: root.hasPlayer ? root.player.loopState : MprisLoopState.None
    readonly property bool shuffling: root.hasPlayer ? root.player.shuffle : false
    readonly property real position: root.hasPlayer ? root.player.position : 0
    readonly property real length: root.hasPlayer ? root.player.length : 0
    readonly property real progress: root.length > 0 ? Math.max(0, Math.min(1, root.position / root.length)) : 0
    readonly property real timeLabelWidth: idPlayerTimeMetrics.advanceWidth
    readonly property string artUrl: root.hasPlayer ? (root.player.trackArtUrl || "") : ""

    RowLayout {
        id: idPlayerRow

        Layout.fillWidth: true

        spacing: Globals.rowSpacing

        CoverArtButton {
            id: idPlayerArt

            Layout.alignment: Qt.AlignVCenter

            source: root.artUrl
            accessibleName: qsTr("Focus Spotify")
            enabled: root.hasPlayer
            onClicked: {
                DashboardService.close();
                HyprlandFocus.focusByTokens(["spotify"]);
            }
        }

        ColumnLayout {
            id: idPlayerContent

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter

            spacing: Globals.listSpacing

            RowLayout {
                id: idPlayerTopLine

                Layout.fillWidth: true

                spacing: Globals.rowSpacing

                ColumnLayout {
                    id: idPlayerMeta

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    spacing: 0

                    Text {
                        id: idPlayerTrack

                        Layout.fillWidth: true
                        Layout.minimumWidth: 0

                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        text: root.hasPlayer ? (root.player.trackTitle || qsTr("Nothing playing")) : qsTr("Nothing playing")
                        color: Colors.text

                        font {
                            family: Globals.uiFontFamily
                            pixelSize: Globals.uiBodySize
                            weight: Font.DemiBold
                        }
                    }

                    Text {
                        id: idPlayerArtist

                        Layout.fillWidth: true
                        Layout.minimumWidth: 0

                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        text: root.hasPlayer ? root.player.trackArtist : ""
                        color: Colors.textSubtle

                        font {
                            family: Globals.uiFontFamily
                            pixelSize: Globals.uiCaptionSize
                        }
                    }
                }

                RowLayout {
                    id: idPlayerDevices

                    Layout.alignment: Qt.AlignVCenter

                    visible: SpotifyService.hasDevices

                    spacing: Globals.listSpacing

                    Repeater {
                        id: idPlayerDevicesRepeater

                        model: SpotifyService.devices

                        delegate: PillButton {
                            id: idPlayerDeviceChip

                            required property var modelData

                            disabled: modelData.isRestricted
                            subtle: true
                            highlighted: modelData.isActive || modelData.id === SpotifyService.pendingDeviceId
                            maxLabelWidth: Globals.playerDeviceLabelWidth
                            text: modelData.name
                            accessibleName: modelData.name
                            onClicked: SpotifyService.transferTo(modelData.id)
                        }
                    }
                }
            }

            RowLayout {
                id: idPlayerScrubber

                Layout.fillWidth: true

                spacing: Globals.rowSpacing

                Text {
                    id: idPlayerElapsed

                    Layout.preferredWidth: root.timeLabelWidth
                    Layout.alignment: Qt.AlignVCenter

                    textFormat: Text.PlainText
                    text: MprisPlayers.formatTime(root.position)
                    color: Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiCaptionSize
                        features: ({ "tnum": 1 })
                    }
                }

                Rectangle {
                    id: idPlayerScrubTrack

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: Globals.eventDotSize
                    Layout.alignment: Qt.AlignVCenter

                    radius: Globals.eventDotSize / 2
                    color: Colors.cardSecondary

                    Rectangle {
                        id: idPlayerScrubFill

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }

                        width: parent.width * root.progress
                        height: parent.height

                        radius: parent.radius
                        color: Colors.accent
                    }

                    MouseArea {
                        id: idPlayerScrubMouse

                        anchors.fill: parent
                        enabled: root.hasPlayer && root.player.canSeek
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!enabled || root.length <= 0)
                                return;
                            const ratio = Math.max(0, Math.min(1, mouse.x / width));
                            root.player.seek(ratio * root.length - root.position);
                        }
                    }
                }

                Text {
                    id: idPlayerDuration

                    Layout.preferredWidth: root.timeLabelWidth
                    Layout.alignment: Qt.AlignVCenter

                    horizontalAlignment: Text.AlignRight
                    textFormat: Text.PlainText
                    text: MprisPlayers.formatTime(root.length)
                    color: Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiCaptionSize
                        features: ({ "tnum": 1 })
                    }
                }
            }

            RowLayout {
                id: idPlayerTransport

                Layout.fillWidth: true

                spacing: Globals.rowSpacing

                PillButton {
                    id: idPlayerShuffle

                    ghost: true
                    subtle: true
                    disabled: !(root.hasPlayer && root.player.shuffleSupported)
                    highlighted: root.shuffling
                    icon: Icons.shuffle
                    iconNudge: -2
                    accessibleName: qsTr("Shuffle")
                    onClicked: MprisPlayers.toggleShuffle()
                }

                Item {
                    id: idPlayerTransportLeft

                    Layout.fillWidth: true
                }

                RowLayout {
                    id: idPlayerTransportCluster

                    spacing: Globals.rowSpacing

                    PillButton {
                        id: idPlayerPrev

                        ghost: true
                        disabled: !(root.hasPlayer && root.player.canGoPrevious)
                        icon: Icons.skipPrevious
                        accessibleName: qsTr("Previous")
                        onClicked: if (root.hasPlayer)
                            root.player.previous()
                    }

                    PillButton {
                        id: idPlayerPlay

                        ghost: true
                        disabled: !(root.hasPlayer && root.player.canTogglePlaying)
                        highlighted: true
                        icon: root.playing ? Icons.pause : Icons.play
                        accessibleName: root.playing ? qsTr("Pause") : qsTr("Play")
                        onClicked: if (root.hasPlayer)
                            root.player.togglePlaying()
                    }

                    PillButton {
                        id: idPlayerNext

                        ghost: true
                        disabled: !(root.hasPlayer && root.player.canGoNext)
                        icon: Icons.skipNext
                        accessibleName: qsTr("Next")
                        onClicked: if (root.hasPlayer)
                            root.player.next()
                    }
                }

                Item {
                    id: idPlayerTransportRight

                    Layout.fillWidth: true
                }

                PillButton {
                    id: idPlayerRepeat

                    ghost: true
                    subtle: true
                    disabled: !(root.hasPlayer && root.player.loopSupported)
                    highlighted: !(root.loopState === MprisLoopState.None)
                    icon: root.loopState === MprisLoopState.Track ? Icons.repeatOnce : Icons.repeat
                    accessibleName: qsTr("Repeat")
                    onClicked: MprisPlayers.cycleRepeat()
                }
            }
        }
    }

    TextMetrics {
        id: idPlayerTimeMetrics

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
            features: ({ "tnum": 1 })
        }

        text: "00:00"
    }
}
