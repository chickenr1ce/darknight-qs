pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.config
import qs.services
import "AudioLogic.js" as AudioLogic
import "StateParsers.js" as StateParsers

Singleton {
    id: root

    readonly property PwNode defaultSink: Pipewire.defaultAudioSink

    property var hiddenKeys: []
    property var orderKeys: []
    property bool osdEnabled: true

    readonly property var sinkNodes: root.orderedNodes(root.discoveredSinkNodes, root.orderKeys)

    readonly property var sinks: {
        const out = [];
        const nodes = root.sinkNodes;
        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i];
            const key = root.keyFor(node);
            if (root.hiddenKeys.indexOf(key) !== -1)
                continue;
            out.push({
                node: node,
                key: key,
                label: root.rawLabelFor(node),
                isDefault: root.isDefaultNode(node)
            });
        }
        return out;
    }

    readonly property var discoveredSinkNodes: {
        const values = Pipewire.nodes && Pipewire.nodes.values ? Pipewire.nodes.values : [];
        const out = [];
        for (let i = 0; i < values.length; i++) {
            if (root.isSinkNode(values[i]))
                out.push(values[i]);
        }
        return out;
    }

    onHiddenKeysChanged: root.persist()
    onOrderKeysChanged: root.persist()
    onOsdEnabledChanged: root.persist()

    StateFile {
        id: idAudioState

        name: "audio-outputs"
        createDir: true
        onParsed: text => root.applySettings(text)
    }

    PwObjectTracker {
        objects: root.sinkNodes
    }

    IpcHandler {
        target: "volume"

        function up(): string {
            root.stepVolume(root.defaultSink, 1);
            return root.volumeStatus();
        }

        function down(): string {
            root.stepVolume(root.defaultSink, -1);
            return root.volumeStatus();
        }

        function set(percent: int): string {
            root.setVolume(root.defaultSink, percent);
            return root.volumeStatus();
        }

        function mute(): string {
            root.toggleMute(root.defaultSink);
            return root.volumeStatus();
        }

        function status(): string {
            return root.volumeStatus();
        }
    }

    function isSinkNode(node): bool {
        return AudioLogic.isSinkNode(node);
    }

    function keyFor(node): string {
        return AudioLogic.keyFor(node);
    }

    function rawLabelFor(node): string {
        return AudioLogic.rawLabelFor(node);
    }

    function isHidden(node): bool {
        return root.hiddenKeys.indexOf(root.keyFor(node)) !== -1;
    }

    function isDefaultNode(node): bool {
        return Boolean(node) && Boolean(root.defaultSink) && node.id === root.defaultSink.id;
    }

    function orderedNodes(nodes, orderKeys): var {
        return AudioLogic.orderedNodes(nodes, orderKeys);
    }

    function setHidden(node, hidden): void {
        const key = root.keyFor(node);
        if (key === "")
            return;
        const next = root.hiddenKeys.slice();
        const index = next.indexOf(key);
        if (hidden && index === -1)
            next.push(key);
        else if (!hidden && index !== -1)
            next.splice(index, 1);
        else
            return;
        root.hiddenKeys = next;
    }

    function moveOutput(node, delta): void {
        const key = root.keyFor(node);
        const order = root.currentOrderKeys();
        const index = order.indexOf(key);
        if (index === -1)
            return;
        const target = index + delta;
        if (target < 0 || target >= order.length)
            return;
        const next = order.slice();
        next.splice(index, 1);
        next.splice(target, 0, key);
        root.orderKeys = next;
    }

    function currentOrderKeys(): var {
        const nodes = root.sinkNodes;
        const out = [];
        for (let i = 0; i < nodes.length; i++)
            out.push(root.keyFor(nodes[i]));
        return out;
    }

    function percentForVolume(volume): int {
        return AudioLogic.percentForVolume(volume);
    }

    function volumeForPercent(percent): real {
        return AudioLogic.volumeForPercent(percent);
    }

    function percentText(volume): string {
        return AudioLogic.percentText(volume);
    }

    function volumeFraction(volume): real {
        return AudioLogic.volumeFraction(volume);
    }

    function setVolume(node, percent): void {
        if (node && node.audio)
            node.audio.volume = root.volumeForPercent(percent);
    }

    function stepVolume(node, direction: int): void {
        if (!node || !node.audio)
            return;
        node.audio.volume = AudioLogic.stepPercent(node.audio.volume * 100, direction, Globals.volumeStep) / 100;
    }

    function toggleMute(node): void {
        if (node && node.audio)
            node.audio.muted = !node.audio.muted;
    }

    function volumeStatus(): string {
        if (!root.defaultSink || !root.defaultSink.audio)
            return "error: no sink";
        return AudioLogic.statusText(root.defaultSink.audio.volume, root.defaultSink.audio.muted);
    }

    function applySettings(jsonText: string): void {
        const parsed = StateParsers.parseAudioSettings(jsonText);
        if (parsed === null)
            return;
        root.hiddenKeys = parsed.hidden;
        root.orderKeys = parsed.order;
        root.osdEnabled = parsed.osdEnabled;
    }

    function persist(): void {
        const payload = {};
        payload["hidden"] = root.hiddenKeys;
        payload["order"] = root.orderKeys;
        payload["osdEnabled"] = root.osdEnabled;
        idAudioState.saveJson(payload);
    }

    function setOsdEnabled(enabled: bool): void {
        if (root.osdEnabled === enabled)
            return;
        root.osdEnabled = enabled;
    }
}
