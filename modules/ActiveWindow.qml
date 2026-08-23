pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.components

// ActiveWindow — focused client title from Hyprland, shown on every bar.
ModuleBox {
    id: root

    // Hyprland only emits "activewindow" with an empty class/title pair when
    // focus leaves all windows; activeToplevel keeps pointing at the previous
    // client, so focus is tracked from the event stream instead. The socket
    // does not replay focus state at connect time, so the initial title is
    // seeded once via hyprctl.
    property string focusedTitle
    property int maxChars: 100

    readonly property string title: root.focusedTitle

    visible: root.title !== ""

    // Iosevka is monospace, so one measured glyph width caps the label at
    // exactly maxChars while Qt does the actual elision.
    maxWidth: Math.ceil(idCharMetrics.advanceWidth * root.maxChars)

    // One-shot seed: the IPC socket only streams changes, so at startup we
    // ask hyprctl for the current window. Skipped if an event already won
    // the race. "Invalid" (nothing focused) fails JSON.parse and clears.
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

    // One-shot seed: the IPC socket only streams changes, so at startup we
    // ask hyprctl for the current window. Skipped if an event already won
    // the race. "Invalid" (nothing focused) fails JSON.parse and clears.
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

        // Payload is CLASS,TITLE and titles may contain commas, hence parse(2).
        function onRawEvent(event): void {
            if (event.name !== "activewindow")
                return;
            root.focusedTitle = event.parse(2)[1] ?? "";
        }
    }
}
