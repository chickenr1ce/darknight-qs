pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

ColumnLayout {
    id: root

    property string label: ""
    property string hint: ""
    property string value: ""
    property var families: []
    property bool expanded: false
    property int maxResults: 40

    readonly property string query: idFontSearch.text.trim()
    readonly property var results: root.filtered()

    signal selected(string family)

    spacing: Globals.spacing

    RowLayout {
        id: idFontRow

        Layout.fillWidth: true

        spacing: Globals.rowSpacing

        Text {
            id: idFontLabel

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: root.label
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }
        }

        Text {
            id: idFontValue

            Layout.alignment: Qt.AlignVCenter

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: root.value
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
                weight: Font.Medium
            }
        }

        PillButton {
            id: idFontToggle

            Layout.alignment: Qt.AlignVCenter

            highlighted: root.expanded
            text: root.expanded ? qsTr("Close") : qsTr("Change")
            accessibleName: qsTr("Choose %1 font").arg(root.label)
            onClicked: root.expanded = !root.expanded
        }
    }

    Text {
        id: idFontHint

        Layout.fillWidth: true

        visible: root.hint !== "" && !root.expanded
        textFormat: Text.PlainText
        text: root.hint
        color: Colors.textSubtle
        wrapMode: Text.WordWrap

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    Rectangle {
        id: idFontSearchField

        Layout.fillWidth: true
        Layout.preferredHeight: idFontSearch.implicitHeight + 2 * Globals.fieldPadding

        visible: root.expanded
        radius: Globals.pillRadius
        color: Colors.cardSecondary
        border.width: Globals.hairlineHeight
        border.color: idFontSearch.activeFocus ? Colors.accent : Colors.border

        TextInput {
            id: idFontSearch

            anchors.fill: parent
            anchors.margins: Globals.fieldPadding

            clip: true
            color: Colors.text
            selectByMouse: true

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }

            Text {
                anchors.fill: parent

                verticalAlignment: Text.AlignVCenter
                visible: idFontSearch.text === "" && !idFontSearch.activeFocus

                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: qsTr("Search fonts…")
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiBodySize
                }
            }
        }
    }

    Repeater {
        id: idFontResults

        model: root.expanded ? root.results : []

        delegate: NavItem {
            id: idFontResult

            Layout.fillWidth: true

            required property string modelData

            text: idFontResult.modelData
            active: idFontResult.modelData === root.value
            onClicked: {
                root.selected(idFontResult.modelData);
                root.collapse();
            }
        }
    }

    Text {
        id: idFontMore

        Layout.fillWidth: true

        visible: root.expanded && root.results.length > 0 && root.families.length > root.results.length
        textFormat: Text.PlainText
        text: qsTr("Showing first %1 — keep typing to narrow.").arg(root.results.length)
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    Text {
        id: idFontEmpty

        Layout.fillWidth: true

        visible: root.expanded && root.results.length === 0
        textFormat: Text.PlainText
        text: qsTr("No match")
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    function filtered(): var {
        const source = root.families;
        const needle = root.query.toLowerCase();
        const out = [];
        if (needle === "") {
            for (let i = 0; i < source.length && out.length < root.maxResults; i++)
                out.push(source[i]);
            return out;
        }
        for (let i = 0; i < source.length && out.length < root.maxResults; i++) {
            if (source[i].toLowerCase().indexOf(needle) !== -1)
                out.push(source[i]);
        }
        return out;
    }

    function collapse(): void {
        root.expanded = false;
        idFontSearch.clear();
    }
}
