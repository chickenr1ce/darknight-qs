pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// ActiveWindow — focused client title from Hyprland, shown on every bar.
ModuleBox {
    id: root

    property ShellScreen triggerScreen: null

    // activeToplevel goes stale and the socket never replays focus, so track it from the event stream seeded once via hyprctl.
    property string focusedTitle
    property int maxChars: 100

    readonly property string title: root.focusedTitle

    visible: root.title !== ""

    onClicked: {
        const centerX = Globals.triggerCenterX(root, root.triggerScreen);
        DashboardService.toggleDashboardAt(root.triggerScreen, centerX);
    }

    // Monospace means one measured glyph caps the label at maxChars; also clamped
    // to the bar interior, past which the compositor clips raw instead of eliding.
    readonly property int maxCharsWidth: Math.ceil(idCharMetrics.advanceWidth * root.maxChars)
    readonly property int visibleBarWidth: parent.width - 2 * Globals.slabInset

    maxWidth: Math.min(root.maxCharsWidth, root.visibleBarWidth)

    Component.onCompleted: idTitleSeedProcess.running = true

    TextMetrics {
        id: idCharMetrics

        font.family: Globals.fontFamily
        font.pixelSize: Globals.fontPixelSize
        text: "M"
    }

    Text {
        id: idWindowLabel

        Layout.fillWidth: true
        Layout.minimumWidth: 0

        text: root.title
        color: Colors.lavender
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.family: Globals.fontFamily
        font.pixelSize: Globals.fontPixelSize
    }

    // One-shot seed: the socket streams changes only. "Invalid" fails JSON.parse and clears; skipped if an event already won the race.
    Process {
        id: idTitleSeedProcess

        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            id: idTitleSeedCollector

            onStreamFinished: {
                if (root.focusedTitle !== "")
                    return;
                try {
                    root.focusedTitle = JSON.parse(idTitleSeedCollector.text).title ?? "";
                } catch (e) {
                    root.focusedTitle = "";
                }
            }
        }
    }

    Connections {
        target: Hyprland

        // Titles may contain commas, hence parse(2).
        function onRawEvent(event): void {
            if (event.name !== "activewindow")
                return;
            root.focusedTitle = event.parse(2)[1] ?? "";
        }
    }
}
