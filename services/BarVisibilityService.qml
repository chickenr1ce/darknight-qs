pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    readonly property var modules: [
        { key: "clock", title: qsTr("Clock") },
        { key: "workspaces", title: qsTr("Workspaces") },
        { key: "tray", title: qsTr("Tray") },
        { key: "cava", title: qsTr("Cava") },
        { key: "media", title: qsTr("Media") },
        { key: "audio", title: qsTr("Audio") },
        { key: "notifications", title: qsTr("Notifications") },
        { key: "power", title: qsTr("Power") }
    ]

    property var moduleVisible: ({})

    onModuleVisibleChanged: {
        if (idVisibilityState.loading || !idVisibilityState.loaded)
            return;
        root.saveVisibility();
    }

    StateFile {
        id: idVisibilityState

        name: "bar-visibility"
        createDir: true
        onParsed: text => root.applyVisibility(text)
    }

    function hasModule(key: string): bool {
        for (let i = 0; i < root.modules.length; i++) {
            if (root.modules[i].key === key)
                return true;
        }
        return false;
    }

    function defaultVisibility(): var {
        const out = {};
        for (let i = 0; i < root.modules.length; i++)
            out[root.modules[i].key] = true;
        return out;
    }

    function isVisible(key: string): bool {
        return !(root.moduleVisible[key] === false);
    }

    function sameVisibility(a, b): bool {
        for (let i = 0; i < root.modules.length; i++) {
            const key = root.modules[i].key;
            if (!(a[key] === b[key]))
                return false;
        }
        return true;
    }

    function parseVisibility(jsonText: string): var {
        const out = root.defaultVisibility();
        let parsed = null;
        try
        {
            parsed = JSON.parse(jsonText);
        }
        catch (e)
        {
            return out;
        }
        if (!parsed || !(typeof parsed === "object"))
            return out;
        for (let i = 0; i < root.modules.length; i++) {
            const key = root.modules[i].key;
            if (parsed[key] === false)
                out[key] = false;
        }
        return out;
    }

    function applyVisibility(jsonText: string): void {
        const next = root.parseVisibility(jsonText);
        if (root.sameVisibility(root.moduleVisible, next))
            return;
        root.moduleVisible = next;
    }

    function saveVisibility(): void {
        const payload = {};
        for (let i = 0; i < root.modules.length; i++) {
            const key = root.modules[i].key;
            payload[key] = !(root.moduleVisible[key] === false);
        }
        idVisibilityState.save(JSON.stringify(payload) + "\n");
    }

    function setVisible(key: string, visible: bool): void {
        if (!root.hasModule(key) || root.isVisible(key) === visible)
            return;
        const next = {};
        for (let i = 0; i < root.modules.length; i++) {
            const k = root.modules[i].key;
            next[k] = k === key ? visible : root.isVisible(k);
        }
        root.moduleVisible = next;
    }
}
