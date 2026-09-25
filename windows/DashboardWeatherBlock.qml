pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

Card {
    id: root

    RowLayout {
        id: idWeatherRow

        Layout.fillWidth: true

        spacing: Globals.rowSpacing

        Text {
            id: idWeatherTemp

            Layout.alignment: Qt.AlignVCenter

            textFormat: Text.PlainText
            text: qsTr("15°C")
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiTitleSize
                weight: Font.DemiBold
            }
        }

        Text {
            id: idWeatherState

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter

            horizontalAlignment: Text.AlignRight
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: qsTr("Clear")
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }
        }
    }
}
