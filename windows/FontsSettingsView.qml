pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

ColumnLayout {
    id: root

    property string filter: ""

    spacing: Globals.spacing

    Repeater {
        id: idFontRoles

        model: FontService.roles

        delegate: FontPickerRow {
            id: idFontRole

            Layout.fillWidth: true

            required property var modelData

            visible: SettingsFilter.matches(root.filter, idFontRole.modelData.label)
            label: idFontRole.modelData.label
            hint: idFontRole.modelData.hint
            value: FontService.familyFor(idFontRole.modelData.key)
            families: FontService.familiesFor(idFontRole.modelData.key)
            onSelected: family => FontService.setFamily(idFontRole.modelData.key, family)
        }
    }
}
