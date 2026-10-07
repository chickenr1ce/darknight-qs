pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string name: ""
    property bool inCache: false
    property string path: root.inCache ? root.cacheFile(root.name) : root.stateFile(root.name)
    property bool createDir: false
    property bool loading: false
    property bool loaded: false
    property bool known: false
    property string knownText: ""

    property Process mkdirProcess: Process {
        running: root.createDir && !(root.path === "")
        command: ["mkdir", "-p", root.parentDir()]
        onExited: root.reload()
    }

    property FileView fileView: FileView {
        path: "file://" + root.path
        printErrors: false
        watchChanges: true
        onFileChanged: root.reload()
        onLoaded: root.applyLoaded()
        onLoadFailed: root.loaded = true
    }

    readonly property string text: root.fileView.text()

    signal parsed(string text)

    function stateBase(): string {
        return Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state");
    }

    function cacheBase(): string {
        return Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache");
    }

    function stateDir(): string {
        return root.stateBase() + "/quickshell";
    }

    function cacheDir(): string {
        return root.cacheBase() + "/quickshell";
    }

    function stateFile(fileName: string): string {
        return root.stateDir() + "/" + fileName;
    }

    function cacheFile(fileName: string): string {
        return root.cacheDir() + "/" + fileName;
    }

    function parentDir(): string {
        const slash = root.path.lastIndexOf("/");
        return slash > 0 ? root.path.slice(0, slash) : "";
    }

    function reload(): void {
        root.fileView.reload();
    }

    function save(contents: string): void {
        if (!root.inCache && (root.loading || !root.loaded))
            return;
        if (root.known && contents === root.knownText)
            return;
        root.knownText = contents;
        root.known = true;
        root.fileView.setText(contents);
    }

    function saveJson(payload): void {
        root.save(JSON.stringify(payload) + "\n");
    }

    function applyLoaded(): void {
        root.loaded = true;
        const loaded = root.text;
        if (root.known && loaded === root.knownText)
            return;
        root.knownText = loaded;
        root.known = true;
        root.loading = true;
        root.parsed(loaded);
        root.loading = false;
    }
}
