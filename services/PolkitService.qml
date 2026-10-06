pragma Singleton

import QtQuick
import Quickshell.Services.Polkit

// Owns the polkit agent for the whole shell. The agent must outlive any dialog
// window, since it has to be registered before a request can arrive.
QtObject {
    id: root

    readonly property PolkitAgent agent: PolkitAgent {
        id: idPolkitAgent
    }

    readonly property bool isRegistered: idPolkitAgent.isRegistered
    readonly property bool isActive: idPolkitAgent.isActive
    readonly property var flow: idPolkitAgent.flow
    readonly property var identities: root.flow ? root.flow.identities : []
    readonly property string identityName: root.flow && root.flow.selectedIdentity ? root.flow.selectedIdentity.string : ""
    readonly property bool hasMultipleIdentities: root.identities.length > 1

    function submit(value: string): void {
        if (root.flow)
            root.flow.submit(value);
    }

    function cancel(): void {
        if (root.flow)
            root.flow.cancelAuthenticationRequest();
    }

    function cycleIdentity(): void {
        if (!root.flow || root.identities.length < 2)
            return;
        const index = root.identities.indexOf(root.flow.selectedIdentity);
        root.flow.selectedIdentity = root.identities[(index + 1) % root.identities.length];
    }
}
