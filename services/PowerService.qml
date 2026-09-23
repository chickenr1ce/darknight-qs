pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property alias powerVisible: idPanelState.visible
    property alias powerLastOutsideCloseAt: idPanelState.lastOutsideCloseAt
    property alias anchorScreen: idPanelState.anchorScreen
    property alias anchorCenterX: idPanelState.anchorCenterX

    property string armedAction: ""
    property string hostName: ""
    property string uptime: ""

    readonly property var actions: [
        { actionId: "lock", label: qsTr("Lock"), glyph: "󰌾", hint: "1", dangerous: false },
        { actionId: "suspend", label: qsTr("Suspend"), glyph: "󰤄", hint: "2", dangerous: false },
        { actionId: "logout", label: qsTr("Logout"), glyph: "󰍃", hint: "3", dangerous: false },
        { actionId: "reboot", label: qsTr("Reboot"), glyph: "󰜉", hint: "4", dangerous: true },
        { actionId: "shutdown", label: qsTr("Shutdown"), glyph: "󰐥", hint: "5", dangerous: true }
    ]

    readonly property string armedLabel: {
        for (let i = 0; i < root.actions.length; i++) {
            if (root.actions[i].actionId === root.armedAction)
                return root.actions[i].label;
        }
        return "";
    }

    readonly property bool armedDangerous: {
        for (let i = 0; i < root.actions.length; i++) {
            if (root.actions[i].actionId === root.armedAction)
                return root.actions[i].dangerous === true;
        }
        return false;
    }

    PanelState {
        id: idPanelState
    }

    Timer {
        id: idInfoTimer

        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!idInfoProcess.running)
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
            if (lines.length > 0 && lines[0].trim() !== "")
                root.hostName = lines[0].trim();
            if (lines.length > 1 && lines[1].trim() !== "")
                root.uptime = lines[1].trim();
        }
    }

    Process {
        id: idRunProcess
    }

    function togglePowerAt(screen, centerX: real) {
        const was = idPanelState.visible;
        idPanelState.toggleAt(screen, centerX);
        if (idPanelState.visible !== was)
            root.armedAction = "";
    }

    function closeFromOutside() {
        idPanelState.closeFromOutside();
        root.armedAction = "";
    }

    function arm(actionId: string) {
        if (actionId === "lock") {
            root.executeAction(actionId);
            return;
        }
        if (root.armedAction === actionId)
            root.confirmArmed();
        else
            root.armedAction = actionId;
    }

    function cancel() {
        root.armedAction = "";
    }

    function confirmArmed() {
        if (root.armedAction === "")
            return;
        root.executeAction(root.armedAction);
    }

    function executeAction(actionId: string) {
        if (actionId === "lock")
            idRunProcess.command = ["sh", "-c", "command -v hyprlock >/dev/null 2>&1 && exec hyprlock || { command -v betterlockscreen >/dev/null 2>&1 && exec betterlockscreen -l || exec i3lock; }"];
        else if (actionId === "suspend")
            idRunProcess.command = ["sh", "-c", "mpc -q pause 2>/dev/null; systemctl suspend"];
        else if (actionId === "logout")
            idRunProcess.command = ["hyprctl", "dispatch", "exit"];
        else if (actionId === "reboot")
            idRunProcess.command = ["systemctl", "reboot"];
        else if (actionId === "shutdown")
            idRunProcess.command = ["systemctl", "poweroff"];
        else
            return;
        idRunProcess.running = true;
        idPanelState.visible = false;
        root.armedAction = "";
    }
}
