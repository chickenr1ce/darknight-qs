pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "PowerLogic.js" as PowerLogic

Singleton {
    id: root

    readonly property PanelState panelState: idPanelState

    readonly property BarAnchor barAnchor: idBarAnchor

    property string armedAction: ""
    property string hostName: ""
    property string uptime: ""

    readonly property var actions: {
        const chrome = {
            lock: { glyph: Icons.lock, hint: "1" },
            suspend: { glyph: Icons.powerSleep, hint: "2" },
            logout: { glyph: Icons.logout, hint: "3" },
            reboot: { glyph: Icons.restart, hint: "4" },
            shutdown: { glyph: Icons.power, hint: "5" },
            winboot: { glyph: Icons.windows, hint: "6" }
        };
        const table = PowerLogic.actions();
        const out = [];
        for (let i = 0; i < table.length; i++) {
            const entry = table[i];
            out.push({
                actionId: entry.id,
                label: entry.label,
                glyph: chrome[entry.id].glyph,
                hint: chrome[entry.id].hint,
                dangerous: entry.dangerous
            });
        }
        return out;
    }

    readonly property string armedLabel: PowerLogic.label(root.armedAction)

    readonly property bool armedDangerous: PowerLogic.dangerous(root.armedAction)

    PanelState {
        id: idPanelState

        onVisibleChanged: root.armedAction = ""
    }

    BarAnchor {
        id: idBarAnchor
    }

    Timer {
        id: idInfoTimer

        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!idInfoProcess.running && !idRunProcess.running)
                idInfoProcess.running = true;
        }
    }

    Process {
        id: idInfoProcess

        command: ["sh", "-c", "hostname; uptime -p | sed -e 's/^up //g'"]
        stdout: idInfoCollector
    }

    StdioCollector {
        id: idInfoCollector

        onStreamFinished: {
            const lines = idInfoCollector.text.split("\n");
            if (lines.length > 0 && !(lines[0].trim() === ""))
                root.hostName = lines[0].trim();
            if (lines.length > 1 && !(lines[1].trim() === ""))
                root.uptime = lines[1].trim();
        }
    }

    Process {
        id: idRunProcess
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            idBarAnchor.requestToggle();
        }

        function close(): void {
            idPanelState.closeFromOutside();
        }
    }

    function arm(actionId: string) {
        root.applyResult(PowerLogic.press({ armed: root.armedAction }, actionId));
    }

    function isArmed(actionId: string): bool {
        return PowerLogic.isArmed({ armed: root.armedAction }, actionId);
    }

    function cancel() {
        root.armedAction = PowerLogic.cancel({ armed: root.armedAction }).armed;
    }

    function confirmArmed() {
        root.applyResult(PowerLogic.confirm({ armed: root.armedAction }));
    }

    function applyResult(result: var) {
        root.armedAction = result.state.armed;
        if (result.run !== null) {
            idRunProcess.command = result.run;
            idRunProcess.running = true;
            idPanelState.visible = false;
        }
    }
}
