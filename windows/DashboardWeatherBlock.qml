pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

Card {
    id: root

    readonly property real heroIconSlot: Math.max(idWeatherPinMetrics.advanceWidth, idWeatherGlyphMetrics.advanceWidth, idWeatherCloudyMetrics.advanceWidth, idWeatherFogMetrics.advanceWidth, idWeatherRainyMetrics.advanceWidth, idWeatherSnowyMetrics.advanceWidth, idWeatherStormMetrics.advanceWidth)

    TextMetrics {
        id: idWeatherPinMetrics

        font.family: Globals.iconFontFamily
        font.pixelSize: Globals.uiCaptionSize
        text: Icons.location
    }

    TextMetrics {
        id: idWeatherGlyphMetrics

        font.family: Globals.iconFontFamily
        font.pixelSize: Globals.uiDisplaySize
        text: Icons.weatherSunny
    }

    TextMetrics {
        id: idWeatherCloudyMetrics

        font.family: Globals.iconFontFamily
        font.pixelSize: Globals.uiDisplaySize
        text: Icons.weatherCloudy
    }

    TextMetrics {
        id: idWeatherFogMetrics

        font.family: Globals.iconFontFamily
        font.pixelSize: Globals.uiDisplaySize
        text: Icons.weatherFog
    }

    TextMetrics {
        id: idWeatherRainyMetrics

        font.family: Globals.iconFontFamily
        font.pixelSize: Globals.uiDisplaySize
        text: Icons.weatherRainy
    }

    TextMetrics {
        id: idWeatherSnowyMetrics

        font.family: Globals.iconFontFamily
        font.pixelSize: Globals.uiDisplaySize
        text: Icons.weatherSnowy
    }

    TextMetrics {
        id: idWeatherStormMetrics

        font.family: Globals.iconFontFamily
        font.pixelSize: Globals.uiDisplaySize
        text: Icons.weatherStorm
    }

    component WeatherMetric: RowLayout {
        id: idWeatherMetric

        property string label: ""
        property string value: ""
        property string rangeLo: ""

        spacing: Globals.fieldPadding

        Text {
            id: idWeatherMetricLabel

            Layout.alignment: Qt.AlignVCenter

            textFormat: Text.PlainText
            text: idWeatherMetric.label
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
                weight: Font.Medium
                letterSpacing: Globals.uiLetterSpacing
            }
        }

        Item {
            id: idWeatherMetricGap

            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }

        RowLayout {
            id: idWeatherMetricGroup

            Layout.alignment: Qt.AlignVCenter

            spacing: Globals.fieldPadding

            Text {
                id: idWeatherMetricValue

                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                text: idWeatherMetric.value
                color: Colors.text

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiPillSize
                    weight: Font.DemiBold
                }
            }

            Text {
                id: idWeatherMetricSlash

                Layout.alignment: Qt.AlignVCenter

                visible: !(idWeatherMetric.rangeLo === "")
                textFormat: Text.PlainText
                text: qsTr("/")
                color: Colors.textSecondary

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                }
            }

            Text {
                id: idWeatherMetricLo

                Layout.alignment: Qt.AlignVCenter

                visible: !(idWeatherMetric.rangeLo === "")
                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: idWeatherMetric.rangeLo
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                }
            }
        }
    }

    RowLayout {
        id: idWeatherRow

        Layout.fillWidth: true
        Layout.fillHeight: true

        spacing: Globals.rowSpacing

        ColumnLayout {
            id: idWeatherHero

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.maximumWidth: Math.max(0, idWeatherRow.width - idWeatherMetrics.implicitWidth - Globals.hairlineHeight - 2 * Globals.rowSpacing)
            Layout.alignment: Qt.AlignVCenter

            spacing: Globals.fieldPadding

            RowLayout {
                id: idWeatherCityRow

                Layout.fillWidth: true

                spacing: Globals.fieldPadding

                Icon {
                    id: idWeatherPin

                    Layout.preferredWidth: root.heroIconSlot
                    Layout.alignment: Qt.AlignVCenter

                    transform: Translate {
                        x: root.heroInkShift(idWeatherPinMetrics)
                    }

                    text: Icons.location
                    size: Globals.uiCaptionSize
                    color: Colors.textSubtle
                }

                Text {
                    id: idWeatherCity

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignVCenter

                    leftPadding: Globals.spacing
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    text: WeatherService.stale ? qsTr("%1 · Stale").arg(WeatherService.city) : WeatherService.city
                    color: Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiCaptionSize
                        weight: Font.Medium
                    }
                }
            }

            RowLayout {
                id: idWeatherTempRow

                Layout.fillWidth: true

                spacing: Globals.spacing

                Icon {
                    id: idWeatherGlyph

                    Layout.preferredWidth: root.heroIconSlot
                    Layout.alignment: Qt.AlignVCenter

                    transform: Translate {
                        x: root.heroInkShift(idWeatherGlyphMetrics)
                    }

                    text: WeatherService.glyph
                    size: Globals.uiDisplaySize
                    color: Colors.accent
                }

                Text {
                    id: idWeatherTemp

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignVCenter

                    leftPadding: Globals.fieldPadding
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: !(WeatherService.tempText === "") ? WeatherService.tempText : qsTr("—")
                    color: Colors.text

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiDisplaySize
                        weight: Font.DemiBold
                    }
                }
            }
        }

        Rectangle {
            id: idWeatherDivider

            Layout.preferredWidth: Globals.hairlineHeight
            Layout.fillHeight: true

            color: Colors.border
        }

        ColumnLayout {
            id: idWeatherMetrics

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter

            spacing: Globals.listSpacing

            WeatherMetric {
                id: idWeatherRain

                Layout.fillWidth: true

                label: qsTr("RAIN")
                value: !(WeatherService.precipText === "") ? WeatherService.precipText : qsTr("—")
            }

            Rectangle {
                id: idWeatherMetricsDivider

                Layout.fillWidth: true
                Layout.preferredHeight: Globals.hairlineHeight

                color: Colors.border
            }

            WeatherMetric {
                id: idWeatherRange

                Layout.fillWidth: true

                label: qsTr("RANGE")
                value: !(WeatherService.highText === "") ? WeatherService.highText : qsTr("—")
                rangeLo: !(WeatherService.lowText === "") ? WeatherService.lowText : qsTr("—")
            }
        }
    }

    function heroInkShift(metrics): real {
        const ink = metrics.tightBoundingRect;
        return metrics.advanceWidth / 2 - (ink.x + ink.width / 2);
    }
}
