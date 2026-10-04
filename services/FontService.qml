pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "StateParsers.js" as StateParsers

Singleton {
    id: root

    readonly property var families: {
        const raw = Qt.fontFamilies();
        const unique = [];
        for (let i = 0; i < raw.length; i++) {
            if (unique.indexOf(raw[i]) === -1)
                unique.push(raw[i]);
        }
        unique.sort((a, b) => a.localeCompare(b));
        return unique;
    }

    readonly property var iconFamilies: root.families.filter(family => family.indexOf("Nerd Font") !== -1)

    readonly property var roles: [
        { key: "ui", label: qsTr("Interface"), hint: qsTr("Dashboard, notifications, and settings text.") },
        { key: "mono", label: qsTr("Bar"), hint: qsTr("Clock, media, and workspace labels in the bar.") },
        { key: "icon", label: qsTr("Icons"), hint: qsTr("Nerd Font glyphs for every icon in the shell.") }
    ]

    StateFile {
        id: idFontState

        name: "font-settings"
        createDir: true
        onParsed: text => root.applySettings(text)
    }

    function familiesFor(key: string): var {
        return key === "icon" ? root.iconFamilies : root.families;
    }

    function familyFor(key: string): string {
        if (key === "mono")
            return Globals.fontFamily;
        if (key === "icon")
            return Globals.iconFontFamily;
        return Globals.uiFontFamily;
    }

    function isAllowed(key: string, family: string): bool {
        return root.familiesFor(key).indexOf(family) !== -1;
    }

    function setFamily(key: string, family: string): void {
        if (!root.applyFamily(key, family))
            return;
        root.saveSettings();
    }

    function applyFamily(key: string, family: string): bool {
        if (!root.isAllowed(key, family))
            return false;
        if (key === "mono") {
            if (family === Globals.fontFamily)
                return false;
            Globals.fontFamily = family;
            return true;
        }
        if (key === "icon") {
            if (family === Globals.iconFontFamily)
                return false;
            Globals.iconFontFamily = family;
            return true;
        }
        if (key !== "ui")
            return false;
        if (family === Globals.uiFontFamily)
            return false;
        Globals.uiFontFamily = family;
        return true;
    }

    function applySettings(jsonText: string): void {
        const parsed = StateParsers.parseFontSettings(jsonText);
        if (parsed === null)
            return;
        if (parsed.uiFamily !== undefined && root.isAllowed("ui", parsed.uiFamily))
            Globals.uiFontFamily = parsed.uiFamily;
        if (parsed.monoFamily !== undefined && root.isAllowed("mono", parsed.monoFamily))
            Globals.fontFamily = parsed.monoFamily;
        if (parsed.iconFamily !== undefined && root.isAllowed("icon", parsed.iconFamily))
            Globals.iconFontFamily = parsed.iconFamily;
    }

    function saveSettings(): void {
        if (idFontState.loading || !idFontState.loaded)
            return;
        const payload = {};
        payload["uiFamily"] = Globals.uiFontFamily;
        payload["monoFamily"] = Globals.fontFamily;
        payload["iconFamily"] = Globals.iconFontFamily;
        idFontState.save(JSON.stringify(payload) + "\n");
    }
}
