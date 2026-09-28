pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode defaultSink: Pipewire.defaultAudioSink

    readonly property var catalog: [
        { match: "JadeAudio", label: qsTr("JadeAudio JIEZI") },
        { match: "AB13X", label: qsTr("AB13X Dongle") },
        { match: "Pebble", label: qsTr("Creative Pebble V3") }
    ]

    readonly property var sinkNodes: {
        const nodes = Pipewire.nodes.values;
        const out = [];
        for (let c = 0; c < root.catalog.length; c++) {
            for (let i = 0; i < nodes.length; i++) {
                const node = nodes[i];
                if (root.isSinkNode(node) && root.matchesCatalog(node, root.catalog[c])) {
                    out.push(node);
                    break;
                }
            }
        }
        return out;
    }

    readonly property var sinks: {
        const out = [];
        for (let i = 0; i < root.sinkNodes.length; i++) {
            const node = root.sinkNodes[i];
            out.push({
                node: node,
                label: root.catalogLabelFor(node),
                isDefault: node === root.defaultSink
            });
        }
        return out;
    }

    PwObjectTracker {
        objects: root.sinkNodes
    }

    function isSinkNode(node): bool {
        return Boolean(node) && node.isSink && !node.isStream && Boolean(node.audio);
    }

    function rawLabelFor(node): string {
        if (!node)
            return "";
        return node.description || node.nickname || node.name || "";
    }

    function matchesCatalog(node, entry): bool {
        return root.rawLabelFor(node).includes(entry.match);
    }

    function catalogLabelFor(node): string {
        for (let i = 0; i < root.catalog.length; i++) {
            if (root.matchesCatalog(node, root.catalog[i]))
                return root.catalog[i].label;
        }
        return root.rawLabelFor(node);
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
}
