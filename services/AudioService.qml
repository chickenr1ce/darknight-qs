pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.services
import "StateParsers.js" as StateParsers

Singleton {
    id: root

    readonly property PwNode defaultSink: Pipewire.defaultAudioSink

    property var hiddenKeys: []
    property var orderKeys: []

    readonly property var sinkNodes: root.orderedNodes(root.discoveredSinkNodes)

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

    StateFile {
        id: idAudioState

        name: "audio-outputs"
        createDir: true
        onParsed: text => root.applySettings(text)
    }

    PwObjectTracker {
        objects: root.sinkNodes
    }

    function isSinkNode(node): bool {
        return Boolean(node) && node.isSink && !node.isStream && Boolean(node.audio);
    }

    function keyFor(node): string {
        if (!node)
            return "";
        return node.name || node.description || node.nickname || String(node.id);
    }

    function rawLabelFor(node): string {
        if (!node)
            return "";
        return node.description || node.nickname || node.name || "";
    }

    function isHidden(node): bool {
        return root.hiddenKeys.indexOf(root.keyFor(node)) !== -1;
    }

    function isDefaultNode(node): bool {
        return Boolean(node) && Boolean(root.defaultSink) && node.id === root.defaultSink.id;
    }

    function orderedNodes(nodes): var {
        const order = root.orderKeys;
        const out = [];
        for (let i = 0; i < order.length; i++) {
            for (let j = 0; j < nodes.length; j++) {
                if (root.keyFor(nodes[j]) === order[i]) {
                    out.push(nodes[j]);
                    break;
                }
            }
        }
        const rest = [];
        for (let j = 0; j < nodes.length; j++) {
            if (order.indexOf(root.keyFor(nodes[j])) === -1)
                rest.push(nodes[j]);
        }
        rest.sort((a, b) => {
            const left = root.rawLabelFor(a).toLowerCase();
            const right = root.rawLabelFor(b).toLowerCase();
            return left < right ? -1 : (left > right ? 1 : 0);
        });
        for (let j = 0; j < rest.length; j++)
            out.push(rest[j]);
        return out;
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
        const value = Number(volume);
        if (isNaN(value))
            return 0;
        return Math.round(Math.max(0, Math.min(1, value)) * 100);
    }

    function volumeForPercent(percent): real {
        const value = Number(percent);
        if (isNaN(value))
            return 0;
        return Math.max(0, Math.min(100, value)) / 100;
    }

    function setVolume(node, percent): void {
        if (node && node.audio)
            node.audio.volume = root.volumeForPercent(percent);
    }

    function applySettings(jsonText: string): void {
        const parsed = StateParsers.parseAudioSettings(jsonText);
        if (parsed === null)
            return;
        root.hiddenKeys = parsed.hidden;
        root.orderKeys = parsed.order;
    }

    function persist(): void {
        if (idAudioState.loading || !idAudioState.loaded)
            return;
        const payload = {};
        payload["hidden"] = root.hiddenKeys;
        payload["order"] = root.orderKeys;
        idAudioState.save(JSON.stringify(payload) + "\n");
    }
}
