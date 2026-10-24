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
        const rows = PowerLogic.rows("bar");
        for (let i = 0; i < rows.length; i++)
            rows[i].glyph = Icons[rows[i].glyph];
        return rows;
    }
    readonly property var confirmKeys: PowerLogic.confirmKeys()
    readonly property string headerSub: PowerLogic.header(root.hostName, root.uptime)
    readonly property string question: PowerLogic.question(root.armedAction)

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

    function pressKey(key: string): void {
        const route = PowerLogic.route("bar", root.armedAction, key);
        if (route.kind === "arm")
            root.arm(route.id);
        else if (route.kind === "confirm")
            root.confirmArmed();
        else if (route.kind === "disarm")
            root.cancel();
        else if (route.kind === "close")
            idPanelState.visible = false;
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
        if (result.lock === true) {
            idPanelState.visible = false;
            LockService.lock();
            return;
        }
        if (result.run !== null) {
            idRunProcess.command = result.run;
            idRunProcess.running = true;
            idPanelState.visible = false;
        }
    }
}
