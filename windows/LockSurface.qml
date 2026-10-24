pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

Item {
    id: root

    property bool preview: false
    property bool capsLock: false
    property double lastKeyAt: 0
    property int tick: 0
    property date now: new Date()

    readonly property real uiScale: Globals.lockBaseHeight > 0 ? root.height / Globals.lockBaseHeight : 1
    readonly property bool engaged: root.preview ? LockService.previewOpen : true
    readonly property string wallpaperSource: root.engaged && ThemeService.backgroundPath !== ""
        ? "file://" + encodeURI(ThemeService.backgroundPath)
        : ""

    readonly property MprisPlayer player: MprisPlayers.activePlayer
    readonly property bool playing: root.player !== null && root.player.playbackState === MprisPlaybackState.Playing
    readonly property string authState: LockService.authState
    readonly property bool powerOpen: LockService.powerOpen
    readonly property bool checking: root.authState === "checking"
    readonly property bool failed: root.authState === "failed"
    readonly property string messageText: LockService.messageText(root.authState, LockService.pamMessage, LockService.pamMessageIsError, LockService.attempts)
    readonly property bool messageIsError: LockService.messageIsError(root.authState, LockService.pamMessage, LockService.pamMessageIsError)
    readonly property string lockedSince: LockService.lockedAt > 0 ? Qt.formatDateTime(new Date(LockService.lockedAt), "HH:mm") : ""
    readonly property string volumeGlyph: AudioService.defaultSink ? AudioService.volumeGlyph(AudioService.defaultSink.audio) : Icons.volumeOff
    readonly property string volumeText: AudioService.defaultSink && AudioService.defaultSink.audio ? AudioService.percentText(AudioService.defaultSink.audio.volume) + "%" : ""
    readonly property bool revealShown: LockService.revealShown({
        fieldLength: idLockField.text.length,
        authState: root.authState,
        powerOpen: root.powerOpen,
        msSinceLastKey: Date.now() - root.lastKeyAt,
        idleMs: Globals.lockIdleHideMs,
        tick: root.tick
    })

    focus: true

    Window.onActiveChanged: {
        if (Window.active)
            root.focusField();
    }

    onAuthStateChanged: {
        if (root.failed && !Globals.reducedMotion)
            idErrorShake.restart();
    }

    onPowerOpenChanged: Qt.callLater(root.focusField)

    Component.onCompleted: Qt.callLater(root.focusField)

    function focusField(): void {
        if (root.powerOpen)
            root.forceActiveFocus();
        else
            idLockField.forceActiveFocus();
    }

    function px(value): int {
        return Math.round(value * root.uiScale);
    }

    function noteInput(): void {
        root.lastKeyAt = Date.now();
        root.tick += 1;
        LockService.clearFailure();
    }

    function noteKeyState(event): void {
        const text = event.text || "";
        const isLetter = text.length === 1 && text.toLowerCase() !== text.toUpperCase();
        const upper = isLetter && text === text.toUpperCase();
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        root.capsLock = LockService.capsLockAfterKey(root.capsLock, event.key === Qt.Key_CapsLock, isLetter, upper, shift);
    }

    function submit(): void {
        const password = idLockField.text;
        if (!LockService.canSubmit(password))
            return;
        idLockField.text = "";
        root.noteInput();
        LockService.submit(password);
    }

    function handleTextKey(event): void {
        root.noteKeyState(event);
        root.noteInput();
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_P) {
            LockService.togglePowerCard();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Escape) {
            idLockField.text = "";
            event.accepted = true;
        }
    }

    function handleKey(event): void {
        if (!root.powerOpen) {
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_P) {
                LockService.togglePowerCard();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                idLockField.text = "";
                event.accepted = true;
            }
            return;
        }
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_P) {
            LockService.togglePowerCard();
            event.accepted = true;
            return;
        }
        let key = event.text;
        if (event.key === Qt.Key_Escape)
            key = "Escape";
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            key = "Return";
        if (key !== "")
            LockService.powerKey(key);
        event.accepted = true;
    }

    Keys.onPressed: event => root.handleKey(event)

    Rectangle {
        id: idBackdrop

        anchors.fill: parent
        color: Colors.background
    }

    Image {
        id: idWallpaper

        anchors.fill: parent

        source: root.wallpaperSource
        sourceSize.width: root.width
        sourceSize.height: root.height
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        visible: false
    }

    MultiEffect {
        id: idWallpaperEffect

        anchors.fill: parent

        source: idWallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blur: Globals.lockWallpaperBlur
        blurMax: root.px(Globals.lockWallpaperBlurMax)
        saturation: Globals.lockWallpaperSaturation
        visible: root.wallpaperSource !== ""
    }

    Rectangle {
        id: idScrim

        anchors.fill: parent

        color: Colors.backgroundSecondary
        opacity: Globals.lockScrimOpacity
    }

    MouseArea {
        id: idBackgroundMouseArea

        anchors.fill: parent

        onClicked: mouse => {
            const cardPoint = idPowerCard.mapFromItem(idBackgroundMouseArea, mouse.x, mouse.y);
            const inCard = cardPoint.x >= 0 && cardPoint.x < idPowerCard.width
                && cardPoint.y >= 0 && cardPoint.y < idPowerCard.height;
            if (root.powerOpen && inCard)
                return;
            if (root.powerOpen)
                LockService.closePower();
            else
                root.focusField();
        }
    }

    Rectangle {
        id: idClockChip

        anchors {
            top: parent.top
            left: parent.left
            topMargin: root.px(Globals.lockChipTop)
            leftMargin: root.px(Globals.lockChipSide)
        }

        width: idClockChipRow.implicitWidth + 2 * root.px(Globals.lockChipClockPadding)
        height: root.px(Globals.lockChipHeight)
        radius: root.px(Globals.slabRadius)
        color: Colors.background
        border.width: root.px(Globals.hairlineHeight)
        border.color: Colors.border

        RowLayout {
            id: idClockChipRow

            anchors {
                fill: parent
                leftMargin: root.px(Globals.lockChipClockPadding)
                rightMargin: root.px(Globals.lockChipClockPadding)
            }

            spacing: root.px(Globals.lockChipGap)

            Icon {
                id: idClockChipGlyph

                Layout.alignment: Qt.AlignVCenter

                text: Icons.lock
                size: root.px(Globals.fontPixelSize)
                color: Colors.accent
            }

            Text {
                id: idClockChipTime

                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                text: Qt.formatDateTime(root.now, "HH:mm")
                color: Colors.text

                font {
                    family: Globals.fontFamily
                    pixelSize: root.px(Globals.lockTimeSize)
                    weight: Font.DemiBold
                }
            }

            Text {
                id: idClockChipDate

                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                text: Qt.formatDateTime(root.now, "ddd d MMM")
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: root.px(Globals.uiCaptionSize)
                }
            }
        }
    }

    Rectangle {
        id: idStatusChip

        anchors {
            top: parent.top
            right: parent.right
            topMargin: root.px(Globals.lockChipTop)
            rightMargin: root.px(Globals.lockChipSide)
        }

        width: idStatusChipRow.implicitWidth + 2 * root.px(Globals.lockChipPadding)
        height: root.px(Globals.lockChipHeight)
        radius: root.px(Globals.slabRadius)
        color: Colors.background
        border.width: root.px(Globals.hairlineHeight)
        border.color: Colors.border

        RowLayout {
            id: idStatusChipRow

            anchors {
                fill: parent
                leftMargin: root.px(Globals.lockChipPadding)
                rightMargin: root.px(Globals.lockChipPadding)
            }

            spacing: root.px(Globals.lockChipPadding)

            Row {
                id: idVolumeRow

                Layout.alignment: Qt.AlignVCenter

                spacing: root.px(Globals.fieldPadding)

                Icon {
                    id: idVolumeGlyph

                    anchors.verticalCenter: parent.verticalCenter

                    text: root.volumeGlyph
                    size: root.px(Globals.fontPixelSize)
                    color: Colors.accent
                }

                Text {
                    id: idVolumeLabel

                    anchors.verticalCenter: parent.verticalCenter

                    visible: root.volumeText !== ""
                    textFormat: Text.PlainText
                    text: root.volumeText
                    color: Colors.accent

                    font {
                        family: Globals.fontFamily
                        pixelSize: root.px(Globals.uiPillSize)
                        weight: Font.DemiBold
                    }
                }
            }

            Rectangle {
                id: idStatusSeparator

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: root.px(Globals.hairlineHeight)
                Layout.preferredHeight: root.px(Globals.lockChipSeparatorHeight)

                color: Colors.border
            }

            PillButton {
                id: idPowerButton

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: root.px(Globals.lockPowerButtonSize)
                Layout.preferredHeight: root.px(Globals.lockPowerButtonSize)

                ghost: true
                subtle: true
                highlighted: root.powerOpen
                icon: Icons.power
                iconSize: root.px(Globals.fontPixelSize)
                accessibleName: qsTr("Power")
                onClicked: LockService.togglePowerCard()
            }
        }
    }

    Text {
        id: idHeroClock

        width: parent.width
        y: root.height * Globals.lockHeroTopFraction

        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: Qt.formatDateTime(root.now, "HH:mm")
        color: Colors.text

        font {
            family: Globals.fontFamily
            pixelSize: root.px(Globals.lockClockSize)
            weight: Font.DemiBold
            letterSpacing: Globals.lockClockLetterSpacing * root.uiScale
        }
    }

    Text {
        id: idHeroDate

        width: parent.width
        y: idHeroClock.y + idHeroClock.height + root.px(Globals.lockHeroDateGap)

        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: Qt.formatDateTime(root.now, "dddd d MMMM")
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: root.px(Globals.lockDateSize)
        }
    }

    Text {
        id: idUnlockHint

        width: parent.width
        y: root.height * Globals.lockCardTopFraction + root.px(Globals.lockHintOffset)

        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: qsTr("Start typing to unlock")
        color: Colors.textSubtle
        opacity: root.revealShown || root.powerOpen ? 0 : 1
        visible: opacity > 0

        font {
            family: Globals.uiFontFamily
            pixelSize: root.px(Globals.uiCaptionSize)
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Globals.reducedMotion ? 0 : Globals.lockRevealMs
                easing.type: Easing.OutQuad
            }
        }
    }

    Card {
        id: idMediaCard

        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: root.px(Globals.lockMediaBottomMargin)
        }

        width: root.px(Globals.lockMediaCardWidth)
        horizontalPadding: root.px(Globals.cardPadding)
        verticalPadding: root.px(Globals.cardPadding)
        radius: root.px(Globals.cardRadius)
        border.width: root.px(Globals.hairlineHeight)
        visible: root.player !== null

        RowLayout {
            id: idMediaRow

            Layout.fillWidth: true

            spacing: root.px(Globals.cardHPadding)

            ClippingRectangle {
                id: idMediaCover

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: root.px(Globals.lockCoverSize)
                Layout.preferredHeight: root.px(Globals.lockCoverSize)

                radius: root.px(Globals.radius)
                color: Colors.cardSecondary
                border.width: root.px(Globals.hairlineHeight)
                border.color: Colors.border

                Image {
                    id: idMediaArt

                    anchors.fill: parent

                    source: root.player ? (root.player.trackArtUrl || "") : ""
                    sourceSize.width: root.px(Globals.lockCoverSize) * 2
                    sourceSize.height: root.px(Globals.lockCoverSize) * 2
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                Icon {
                    id: idMediaPlaceholder

                    anchors.centerIn: parent

                    visible: idMediaArt.status !== Image.Ready
                    text: Icons.music
                    size: root.px(Globals.uiDisplaySize)
                    color: Colors.textSecondary
                }
            }

            ColumnLayout {
                id: idMediaMeta

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: root.px(Globals.lockMediaMetaWidth)
                Layout.alignment: Qt.AlignVCenter

                spacing: root.px(Globals.fieldPadding)

                Text {
                    id: idMediaTitle

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: root.player ? (root.player.trackTitle || "") : ""
                    color: Colors.text

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: root.px(Globals.uiBodySize)
                        weight: Font.DemiBold
                    }
                }

                Text {
                    id: idMediaArtist

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    visible: idMediaArtist.text !== ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: root.player ? (root.player.trackArtist || "") : ""
                    color: Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: root.px(Globals.uiCaptionSize)
                    }
                }

                Item {
                    id: idMediaTrack

                    Layout.fillWidth: true
                    Layout.preferredHeight: root.px(Globals.meterHeight)

                    visible: MprisPlayers.hasProgress

                    Rectangle {
                        id: idMediaTrackBackground

                        anchors.fill: parent

                        radius: height / 2
                        color: Colors.surface
                    }

                    Rectangle {
                        id: idMediaTrackFill

                        width: idMediaTrack.width * MprisPlayers.progress
                        height: parent.height
                        radius: height / 2
                        color: Colors.accent
                    }
                }
            }

            Row {
                id: idMediaButtons

                Layout.alignment: Qt.AlignVCenter

                spacing: root.px(Globals.lockMediaButtonGap)

                IconButton {
                    id: idMediaPrevious

                    glyph: Icons.skipPrevious
                    glyphSize: root.px(Globals.fontPixelSize)
                    restColor: Colors.textSubtle
                    hoverColor: Colors.accent
                    disabled: root.player === null || !root.player.canGoPrevious
                    accessibleName: qsTr("Previous")
                    onClicked: {
                        if (root.player && root.player.canGoPrevious)
                            root.player.previous();
                    }
                }

                IconButton {
                    id: idMediaPlayPause

                    glyph: root.playing ? Icons.pause : Icons.play
                    glyphSize: root.px(Globals.fontPixelSize)
                    restColor: Colors.accent
                    hoverColor: Colors.accent
                    disabled: root.player === null
                    accessibleName: root.playing ? qsTr("Pause") : qsTr("Play")
                    onClicked: {
                        if (root.player === null)
                            return;
                        if (root.player.togglePlaying)
                            root.player.togglePlaying();
                        else if (root.player.playPause)
                            root.player.playPause();
                    }
                }

                IconButton {
                    id: idMediaNext

                    glyph: Icons.skipNext
                    glyphSize: root.px(Globals.fontPixelSize)
                    restColor: Colors.textSubtle
                    hoverColor: Colors.accent
                    disabled: root.player === null || !root.player.canGoNext
                    accessibleName: qsTr("Next")
                    onClicked: {
                        if (root.player && root.player.canGoNext)
                            root.player.next();
                    }
                }
            }
        }
    }

    Card {
        id: idRevealCard

        anchors.horizontalCenter: parent.horizontalCenter

        width: root.px(Globals.lockCardWidth)
        y: root.height * Globals.lockCardTopFraction + (root.revealShown ? 0 : root.px(Globals.lockCardSlide))
        horizontalPadding: root.px(Globals.lockCardPadding)
        verticalPadding: root.px(Globals.lockCardPadding)
        contentSpacing: root.px(Globals.spacing)
        radius: root.px(Globals.cardRadius)
        border.width: root.px(Globals.hairlineHeight)
        opacity: root.revealShown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Globals.reducedMotion ? 0 : Globals.lockRevealMs
                easing.type: Easing.OutQuad
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Globals.reducedMotion ? 0 : Globals.lockRevealMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Globals.easeOutCurve
            }
        }

        RowLayout {
            id: idRevealWho

            Layout.fillWidth: true

            spacing: root.px(Globals.lockFieldGap)

            Rectangle {
                id: idAvatar

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: root.px(Globals.lockAvatarSize)
                Layout.preferredHeight: root.px(Globals.lockAvatarSize)

                radius: height / 2
                color: Colors.accent

                Text {
                    id: idAvatarInitial

                    anchors.centerIn: parent

                    textFormat: Text.PlainText
                    text: LockService.userInitial
                    color: Colors.onAccent

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: root.px(Globals.uiCaptionSize)
                        weight: Font.Bold
                    }
                }
            }

            Text {
                id: idUserName

                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: LockService.userName
                color: Colors.text

                font {
                    family: Globals.uiFontFamily
                    pixelSize: root.px(Globals.uiBodySize)
                    weight: Font.DemiBold
                }
            }

            Item {
                id: idRevealWhoSpacer

                Layout.fillWidth: true
            }

            Text {
                id: idLockedSince

                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                text: qsTr("locked since %1").arg(root.lockedSince)
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: root.px(Globals.uiCaptionSize)
                }
            }
        }

        Rectangle {
            id: idField

            Layout.fillWidth: true
            Layout.preferredHeight: root.px(Globals.lockFieldHeight)

            radius: root.px(Globals.cardRadius)
            color: root.failed ? Colors.criticalCard : Colors.cardSecondary
            border.width: root.px(Globals.hairlineHeight)
            border.color: root.failed ? Colors.criticalCardBorder : (idLockField.text !== "" ? Colors.mixInto(Colors.surface, Colors.accent, Globals.lockFieldFocusMix) : Colors.border)

            transform: Translate {
                id: idFieldTranslate

                x: 0
            }

            RowLayout {
                id: idFieldRow

                anchors {
                    fill: parent
                    leftMargin: root.px(Globals.lockFieldPadding)
                    rightMargin: root.px(Globals.lockFieldPadding)
                }

                spacing: root.px(Globals.lockFieldGap)

                Icon {
                    id: idFieldGlyph

                    Layout.alignment: Qt.AlignVCenter

                    text: Icons.lock
                    size: root.px(Globals.fontPixelSize)
                    color: root.failed ? Colors.danger : (idLockField.text !== "" ? Colors.accent : Colors.textSubtle)
                }

                TextInput {
                    id: idLockField

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignVCenter

                    enabled: !root.powerOpen
                    readOnly: root.checking
                    clip: true
                    selectByMouse: false
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                    color: root.checking ? Colors.accent : Colors.text

                    font {
                        family: Globals.fontFamily
                        pixelSize: root.px(Globals.uiBodySize)
                        letterSpacing: Globals.lockDotLetterSpacing * root.uiScale
                    }

                    onTextChanged: root.noteInput()
                    onAccepted: root.submit()
                    Keys.onPressed: event => root.handleTextKey(event)

                    Text {
                        id: idFieldPlaceholder

                        anchors.fill: parent

                        visible: idLockField.text === "" && !root.failed
                        verticalAlignment: Text.AlignVCenter
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        text: qsTr("Password")
                        color: Colors.textFaint

                        font {
                            family: Globals.uiFontFamily
                            pixelSize: root.px(Globals.uiBodySize)
                        }
                    }
                }

                Rectangle {
                    id: idCapsChip

                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: idCapsLabel.implicitWidth + 2 * root.px(Globals.fieldPadding)
                    Layout.preferredHeight: idCapsLabel.implicitHeight + 2 * root.px(Globals.hairlineHeight)

                    visible: root.capsLock
                    radius: root.px(Globals.pillRadius)
                    color: Colors.mixInto(Colors.background, Colors.yellow, Globals.lockCapsTint)

                    Text {
                        id: idCapsLabel

                        anchors.centerIn: parent

                        textFormat: Text.PlainText
                        text: qsTr("CAPS")
                        color: Colors.yellow

                        font {
                            family: Globals.fontFamily
                            pixelSize: root.px(Globals.lockCapsSize)
                            weight: Font.DemiBold
                        }
                    }
                }

                Item {
                    id: idSpinner

                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: root.px(Globals.lockSpinnerSize)
                    Layout.preferredHeight: root.px(Globals.lockSpinnerSize)

                    opacity: root.checking ? 1 : 0

                    Rectangle {
                        id: idSpinnerRing

                        anchors.fill: parent

                        radius: width / 2
                        color: Colors.cardSecondary
                        border.width: root.px(Globals.lockSpinnerWidth)
                        border.color: Colors.surface
                    }

                    Shape {
                        id: idSpinnerArc

                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            id: idSpinnerPath

                            strokeColor: Colors.accent
                            strokeWidth: root.px(Globals.lockSpinnerWidth)
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathAngleArc {
                                id: idSpinnerSweep

                                centerX: idSpinner.width / 2
                                centerY: idSpinner.height / 2
                                radiusX: idSpinner.width / 2 - root.px(Globals.lockSpinnerWidth) / 2
                                radiusY: idSpinner.height / 2 - root.px(Globals.lockSpinnerWidth) / 2
                                startAngle: -90
                                sweepAngle: 90
                            }
                        }
                    }

                    RotationAnimator {
                        id: idSpinnerRotation

                        target: idSpinner
                        from: 0
                        to: 360
                        duration: Globals.lockSpinnerTurnMs
                        loops: Animation.Infinite
                        running: root.checking && !Globals.reducedMotion
                    }
                }
            }

            SequentialAnimation {
                id: idErrorShake

                NumberAnimation { target: idFieldTranslate; property: "x"; to: -root.px(Globals.lockShakeAmplitude); duration: Globals.lockShakeStepMs }
                NumberAnimation { target: idFieldTranslate; property: "x"; to: Math.round(root.px(Globals.lockShakeAmplitude) * 0.875); duration: Globals.lockShakeStepMs }
                NumberAnimation { target: idFieldTranslate; property: "x"; to: -Math.round(root.px(Globals.lockShakeAmplitude) * 0.5); duration: Globals.lockShakeStepMs }
                NumberAnimation { target: idFieldTranslate; property: "x"; to: Math.round(root.px(Globals.lockShakeAmplitude) * 0.25); duration: Globals.lockShakeStepMs }
                NumberAnimation { target: idFieldTranslate; property: "x"; to: 0; duration: Globals.lockShakeStepMs }
            }
        }

        Text {
            id: idMessage

            Layout.fillWidth: true
            Layout.minimumHeight: root.px(Globals.lockMessageHeight)

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: root.messageText
            color: root.messageIsError ? Colors.danger : Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: root.px(Globals.uiCaptionSize)
            }
        }
    }

    Card {
        id: idPowerCard

        x: root.width - root.px(Globals.lockChipSide) - width
        y: root.px(Globals.lockChipTop) + root.px(Globals.lockChipHeight) + root.px(Globals.lockPowerCardGap) + (root.powerOpen ? 0 : -root.px(Globals.lockPowerCardSlide))
        width: root.px(Globals.lockPowerCardWidth)
        horizontalPadding: root.px(Globals.lockChipPadding)
        verticalPadding: 0
        contentSpacing: 0
        radius: root.px(Globals.cardRadius)
        border.width: root.px(Globals.hairlineHeight)
        opacity: root.powerOpen ? 1 : 0
        visible: root.powerOpen || opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Globals.reducedMotion ? 0 : Globals.hoverMs
                easing.type: Easing.OutQuad
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Globals.reducedMotion ? 0 : Globals.hoverMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Globals.easeOutCurve
            }
        }

        RowLayout {
            id: idPowerHeader

            Layout.fillWidth: true
            Layout.leftMargin: root.px(Globals.cardHPadding)
            Layout.rightMargin: root.px(Globals.cardHPadding)
            Layout.topMargin: root.px(Globals.cardPadding)
            Layout.bottomMargin: root.px(Globals.cardPadding)

            spacing: root.px(Globals.rowSpacing)

            Text {
                id: idPowerTitle

                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                text: qsTr("Power")
                color: Colors.text

                font {
                    family: Globals.uiFontFamily
                    pixelSize: root.px(Globals.uiTitleSize)
                    weight: Font.DemiBold
                }
            }

            Text {
                id: idPowerSub

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: PowerService.headerSub
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: root.px(Globals.uiCaptionSize)
                }
            }
        }

        Column {
            id: idPowerRows

            Layout.fillWidth: true

            spacing: 0

            Repeater {
                id: idPowerRepeater

                model: LockService.powerActions

                delegate: PowerActionRow {
                    required property var modelData
                    required property int index

                    width: idPowerRows.width
                    glyphSize: root.px(Globals.uiDisplaySize)
                    layoutScale: root.uiScale
                    label: modelData ? modelData.label : ""
                    glyph: modelData ? modelData.glyph : ""
                    hint: modelData ? modelData.hint : ""
                    armed: modelData !== null && modelData !== undefined && LockService.powerArmed === modelData.id
                    separator: index < LockService.powerActions.length - 1

                    onActivated: LockService.armPower(modelData ? modelData.id : "")
                }
            }
        }

        Rectangle {
            id: idPowerFooterRule

            Layout.fillWidth: true
            Layout.preferredHeight: root.px(Globals.hairlineHeight)

            color: Colors.border
        }

        RowLayout {
            id: idPowerFooter

            Layout.fillWidth: true
            Layout.leftMargin: root.px(Globals.cardHPadding)
            Layout.rightMargin: root.px(Globals.cardHPadding)
            Layout.topMargin: root.px(Globals.cardPadding)
            Layout.bottomMargin: root.px(Globals.cardPadding)

            spacing: root.px(Globals.rowSpacing)

            Text {
                id: idPowerQuestion

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: LockService.powerQuestion
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: root.px(Globals.uiCaptionSize)
                }
            }

            PillButton {
                id: idPowerCancel

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: root.px(Globals.lockPowerActionHeight)

                disabled: LockService.powerArmed === ""
                labelSize: root.px(Globals.uiPillSize)
                text: qsTr("Cancel")
                onClicked: LockService.cancelPower()
            }

            PillButton {
                id: idPowerConfirm

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: root.px(Globals.lockPowerActionHeight)

                disabled: LockService.powerArmed === ""
                highlighted: !(LockService.powerArmed === "")
                labelSize: root.px(Globals.uiPillSize)
                text: qsTr("Confirm")
                onClicked: LockService.confirmPower()
            }
        }
    }

    Timer {
        id: idClockTimer

        interval: Globals.lockClockTickMs
        running: root.engaged
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Timer {
        id: idRevealTickTimer

        interval: Globals.lockRevealTickMs
        running: root.engaged
        repeat: true
        onTriggered: root.tick += 1
    }

    Connections {
        id: idPreviewConnections

        target: LockService

        enabled: root.preview

        function onPreviewPhaseChanged(): void {
            const phase = LockService.previewPhase;
            const typing = phase === "typing" || phase === "checking";
            idLockField.text = typing ? "preview" : "";
            if (typing || phase === "failed")
                root.lastKeyAt = Date.now();
            else
                root.lastKeyAt = 0;
            root.tick += 1;
        }
    }
}
