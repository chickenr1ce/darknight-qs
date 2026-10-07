pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.services
import "StateParsers.js" as StateParsers

Singleton {
    id: root

    readonly property var rows: [
        { key: "top", label: qsTr("Top margin"), hint: qsTr("Gap between the bar and the top of the screen."), max: Globals.barTopMarginMax },
        { key: "side", label: qsTr("Side margin"), hint: qsTr("Gap between the bar and the screen edges."), max: Globals.barSideMarginMax }
    ]

    StateFile {
        id: idMarginState

        name: "bar-margins"
        createDir: true
        onParsed: text => root.applySettings(text)
    }

    function valueFor(key: string): int {
        return key === "side" ? Globals.barSideMargin : Globals.barTopMargin;
    }

    function maximumFor(key: string): int {
        return key === "side" ? Globals.barSideMarginMax : Globals.barTopMarginMax;
    }

    function clampMargin(key: string, value, fallback: int): int {
        const n = Math.round(Number(value));
        if (isNaN(n))
            return fallback;
        return Math.max(0, Math.min(root.maximumFor(key), n));
    }

    function setMargin(key: string, value): void {
        const current = root.valueFor(key);
        const next = root.clampMargin(key, value, current);
        if (next === current)
            return;
        if (key === "side")
            Globals.barSideMargin = next;
        else
            Globals.barTopMargin = next;
        root.saveSettings();
    }

    function applySettings(jsonText: string): void {
        const parsed = StateParsers.parseBarMargins(jsonText);
        if (parsed === null)
            return;
        if (parsed.topMargin !== undefined)
            Globals.barTopMargin = root.clampMargin("top", parsed.topMargin, Globals.barTopMargin);
        if (parsed.sideMargin !== undefined)
            Globals.barSideMargin = root.clampMargin("side", parsed.sideMargin, Globals.barSideMargin);
    }

    function saveSettings(): void {
        const payload = {};
        payload["topMargin"] = Globals.barTopMargin;
        payload["sideMargin"] = Globals.barSideMargin;
        idMarginState.saveJson(payload);
    }
}
