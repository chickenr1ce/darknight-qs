pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "ThemeParsers.js" as ThemeParsers

Singleton {
    id: root

    readonly property color fallbackColor: "transparent"
    readonly property string themeRoot: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/quickshell/themes"
    readonly property string colorsFileName: "colors.toml"
    readonly property string colorsPath: root.themePathAllowed(root.activeTheme) ? root.themeRoot + "/" + root.activeTheme + "/" + root.colorsFileName : ""

    property string activeTheme: ""
    readonly property string activeDisplayName: root.catalogDisplayName(root.activeTheme)
    property string backgroundsJson: "{}"
    readonly property var backgrounds: ThemeParsers.parseBackgrounds(root.backgroundsJson)
    readonly property string backgroundsDir: root.backgroundDirFor(root.activeTheme)
    property string appliedBackgroundPath: ""
    property string backgroundQueuedPath: ""
    property int backgroundAttempts: 0

    readonly property string catalogScriptPath: Quickshell.shellDir + "/scripts/theme-catalog-scan.sh"
    readonly property string renderScriptPath: Quickshell.shellDir + "/scripts/render-theme.sh"
    readonly property string backgroundsScriptPath: Quickshell.shellDir + "/scripts/theme-backgrounds-scan.sh"
    property string catalogText: ""
    property bool catalogQueued: false
    property bool catalogReady: false
    property string renderPaletteJson: ""
    property bool renderQueued: false
    property string backgroundsListText: ""
    property string backgroundsListDir: ""
    property string backgroundScanDir: ""
    property bool backgroundsQueued: false
    readonly property var catalog: ThemeParsers.parseCatalog(root.catalogText, root.themeRoot)
    readonly property var backgroundList: ThemeParsers.parseBackgroundList(root.backgroundsListText, root.backgroundsListDir)
    readonly property string rememberedBackgroundName: {
        const saved = root.backgrounds[root.activeTheme];
        return typeof saved === "string" ? saved : "";
    }
    readonly property string currentBackgroundName: {
        const entries = root.backgroundList;
        const remembered = root.rememberedBackgroundName;
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].name === remembered)
                return remembered;
        }
        return entries.length > 0 ? entries[0].name : "";
    }
    readonly property string currentBackgroundPath: {
        const entry = root.backgroundEntry(root.currentBackgroundName);
        return entry !== null ? entry.path : "";
    }

    property bool colorsTrusted: false
    property string statPath: ""
    property bool statQueued: false

    property bool hasPalette: false
    property string mode: ""

    property color accent: root.fallbackColor
    property color selection: root.fallbackColor
    property color muted: root.fallbackColor
    property color background: root.fallbackColor
    property color dark_background: root.fallbackColor
    property color darker_background: root.fallbackColor
    property color lighter_background: root.fallbackColor
    property color foreground: root.fallbackColor
    property color dark_foreground: root.fallbackColor
    property color light_foreground: root.fallbackColor
    property color bright_foreground: root.fallbackColor
    property color red: root.fallbackColor
    property color yellow: root.fallbackColor
    property color green: root.fallbackColor
    property color cyan: root.fallbackColor
    property color blue: root.fallbackColor
    property color magenta: root.fallbackColor
    property color bright_red: root.fallbackColor
    property color bright_yellow: root.fallbackColor
    property color bright_green: root.fallbackColor
    property color bright_cyan: root.fallbackColor
    property color bright_blue: root.fallbackColor
    property color bright_magenta: root.fallbackColor
    property color orange: root.fallbackColor
    property color brown: root.fallbackColor
    property color hyprland_active_border: root.fallbackColor
    property color hyprland_inactive_border: root.fallbackColor

    onActiveThemeChanged: {
        root.refreshBackgrounds();
        root.reloadPalette();
        root.saveSelection();
    }
    onBackgroundsJsonChanged: root.saveSelection()
    onRenderPaletteJsonChanged: Qt.callLater(root.renderDesktop)
    Component.onCompleted: root.refresh()

    StateFile {
        id: idThemeState

        name: "theme"
        createDir: true
        onParsed: text => root.applySelection(text)
    }

    Process {
        id: idCatalogProcess

        command: ["sh", root.catalogScriptPath, root.themeRoot, String(ThemeParsers.themeMaxBytes())]
        stdout: StdioCollector {
            id: idCatalogCollector

            onStreamFinished: {
                root.catalogText = idCatalogCollector.text;
                root.catalogReady = true;
                root.reconcileActiveTheme();
                if (root.catalogQueued) {
                    root.catalogQueued = false;
                    Qt.callLater(root.refresh);
                }
            }
        }
    }

    Process {
        id: idStatProcess

        command: ["stat", "-c", "%f|%s", root.colorsPath]
        stdout: idStatCollector
    }

    Process {
        id: idRenderProcess

        command: ["sh", root.renderScriptPath, root.renderPaletteJson]
        onExited: code => {
            if (code !== 0)
                console.warn("ThemeService: render-theme.sh exited non-zero (" + code + ")");
            if (root.renderQueued) {
                root.renderQueued = false;
                Qt.callLater(root.renderDesktop);
            }
        }
    }

    Process {
        id: idBackgroundScanProcess

        stdout: StdioCollector {
            id: idBackgroundScanCollector

            onStreamFinished: root.applyBackgroundScan(idBackgroundScanCollector.text)
        }
    }

    Process {
        id: idBackgroundApplyProcess

        onExited: code => root.backgroundApplyExited(code)
    }

    Timer {
        id: idBackgroundRetryTimer

        interval: 2000
        repeat: false
        onTriggered: root.applyCurrentBackground()
    }

    StdioCollector {
        id: idStatCollector

        onStreamFinished: root.applyStat(idStatCollector.text)
    }

    FileView {
        id: idPaletteFile

        path: root.colorsTrusted && root.colorsPath !== "" ? "file://" + root.colorsPath : ""
        watchChanges: true
        printErrors: false
        onLoaded: root.applyPalette(ThemeParsers.parseColors(idPaletteFile.text()))
        onLoadFailed: root.paletteLoadFailed()
        onFileChanged: root.reloadPalette()
    }

    IpcHandler {
        target: "theme"

        function refresh(): string {
            root.refresh();
            root.reloadPalette();
            return "ok: refreshed";
        }

        function list(): string {
            const themes = root.catalog;
            const lines = [];
            for (let i = 0; i < themes.length; i++) {
                const theme = themes[i];
                lines.push((theme.name === root.activeTheme ? "* " : "  ") + theme.name + " (" + theme.mode + ")");
            }
            return lines.join("\n");
        }

        function current(): string {
            return root.activeTheme;
        }

        function set(name: string): string {
            if (name !== root.activeTheme && !root.selectTheme(name))
                return "error: no theme named " + ThemeParsers.displaySafe(name);
            return "ok: " + name;
        }

        function background(file: string): string {
            return root.selectBackground(file);
        }
    }

    function applySelection(jsonText: string): void {
        const selection = ThemeParsers.parseSelection(jsonText);
        const hadTheme = root.activeTheme !== "";
        root.backgroundsJson = JSON.stringify(selection.backgrounds);
        root.activeTheme = selection.theme;
        root.reconcileActiveTheme();
        if (root.activeTheme === "" && !hadTheme)
            root.reloadPalette();
    }

    function themePathAllowed(theme: string): bool {
        if (theme === "")
            return false;
        return !root.catalogReady || root.hasTheme(theme);
    }

    function reconcileActiveTheme(): void {
        if (!root.catalogReady || root.activeTheme === "")
            return;
        if (root.hasTheme(root.activeTheme))
            return;
        root.activeTheme = "";
    }

    function saveSelection(): void {
        if (idThemeState.loading || !idThemeState.loaded)
            return;
        idThemeState.save(ThemeParsers.serializeSelection(root.activeTheme, root.backgroundsJson));
    }

    function refresh(): void {
        root.refreshBackgrounds();
        if (idCatalogProcess.running) {
            root.catalogQueued = true;
            return;
        }
        idCatalogProcess.running = true;
    }

    function catalogDisplayName(name: string): string {
        const entry = root.catalogEntry(name);
        return entry ? entry.displayName : "";
    }

    function catalogEntry(name: string): var {
        const themes = root.catalog;
        for (let i = 0; i < themes.length; i++) {
            if (themes[i].name === name)
                return themes[i];
        }
        return null;
    }

    function hasTheme(name: string): bool {
        return root.catalogEntry(name) !== null;
    }

    function selectTheme(name: string): bool {
        if (name === root.activeTheme)
            return false;
        if (!root.hasTheme(name))
            return false;
        root.activeTheme = name;
        return true;
    }

    function renderDesktop(): void {
        if (idRenderProcess.running) {
            root.renderQueued = true;
            return;
        }
        idRenderProcess.running = true;
        root.applyCurrentBackground();
    }

    function backgroundEntry(name: string): var {
        const entries = root.backgroundList;
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].name === name)
                return entries[i];
        }
        return null;
    }

    function backgroundDirFor(theme: string): string {
        if (!root.themePathAllowed(theme))
            return "";
        return root.themeRoot + "/" + theme + "/backgrounds";
    }

    function refreshBackgrounds(): void {
        const dir = root.backgroundDirFor(root.activeTheme);
        root.backgroundsListText = "";
        root.backgroundsListDir = "";
        root.backgroundAttempts = 0;
        if (dir === "")
            return;
        if (idBackgroundScanProcess.running) {
            root.backgroundsQueued = true;
            return;
        }
        root.backgroundScanDir = dir;
        idBackgroundScanProcess.exec(["sh", root.backgroundsScriptPath, dir, String(ThemeParsers.backgroundMaxBytes())]);
    }

    function applyBackgroundScan(output: string): void {
        if (root.backgroundScanDir === root.backgroundsDir && root.backgroundsDir !== "") {
            root.backgroundsListDir = root.backgroundScanDir;
            root.backgroundsListText = output;
            root.applyCurrentBackground();
        }
        if (root.backgroundsQueued) {
            root.backgroundsQueued = false;
            Qt.callLater(root.refreshBackgrounds);
        }
    }

    function applyCurrentBackground(): void {
        root.applyBackground(root.currentBackgroundPath);
    }

    function applyBackground(path: string): void {
        if (path === "")
            return;
        if (idBackgroundApplyProcess.running) {
            root.backgroundQueuedPath = path;
            return;
        }
        if (path === root.appliedBackgroundPath)
            return;
        root.appliedBackgroundPath = path;
        idBackgroundApplyProcess.exec(["awww", "img", path]);
    }

    function backgroundApplyExited(code: int): void {
        if (code === 0) {
            root.backgroundAttempts = 0;
        } else if (root.currentBackgroundPath !== "") {
            root.appliedBackgroundPath = "";
            if (root.backgroundAttempts < 5) {
                root.backgroundAttempts += 1;
                idBackgroundRetryTimer.restart();
            }
        }
        if (root.backgroundQueuedPath !== "") {
            const queued = root.backgroundQueuedPath;
            root.backgroundQueuedPath = "";
            Qt.callLater(() => root.applyBackground(queued));
        }
    }

    function selectBackground(file: string): string {
        if (root.activeTheme === "")
            return "error: no active theme";
        const name = ThemeParsers.backgroundName(file);
        if (name === "")
            return "error: not a background image: " + ThemeParsers.displaySafe(file);
        const entry = root.backgroundEntry(name);
        if (entry === null)
            return "error: no background named " + ThemeParsers.displaySafe(name) + " in this theme";
        const updated = ThemeParsers.parseBackgrounds(root.backgroundsJson);
        updated[root.activeTheme] = name;
        root.backgroundsJson = JSON.stringify(updated);
        root.applyBackground(entry.path);
        return "ok: " + name;
    }

    function reloadPalette(): void {
        root.colorsTrusted = false;
        root.applyPalette(null);
        if (root.activeTheme === "") {
            Qt.callLater(root.renderDesktop);
            return;
        }
        Qt.callLater(root.statPalette);
    }

    function paletteLoadFailed(): void {
        root.colorsTrusted = false;
        root.applyPalette(null);
    }

    function statPalette(): void {
        if (root.colorsPath === "")
            return;
        if (idStatProcess.running) {
            root.statQueued = true;
            return;
        }
        root.statPath = root.colorsPath;
        idStatProcess.running = true;
    }

    function applyStat(output: string): void {
        if (root.statPath === root.colorsPath && ThemeParsers.isTrustedStat(output)) {
            root.colorsTrusted = true;
        } else {
            root.colorsTrusted = false;
            root.applyPalette(null);
        }
        if (root.statQueued) {
            root.statQueued = false;
            Qt.callLater(root.statPalette);
        }
    }

    function applyPalette(palette): void {
        const present = palette !== null && palette !== undefined;
        const pick = key => present && palette[key] !== undefined ? palette[key] : root.fallbackColor;
        root.mode = present ? palette.mode : "";
        root.accent = pick("accent");
        root.selection = pick("selection");
        root.muted = pick("muted");
        root.background = pick("background");
        root.dark_background = pick("dark_background");
        root.darker_background = pick("darker_background");
        root.lighter_background = pick("lighter_background");
        root.foreground = pick("foreground");
        root.dark_foreground = pick("dark_foreground");
        root.light_foreground = pick("light_foreground");
        root.bright_foreground = pick("bright_foreground");
        root.red = pick("red");
        root.yellow = pick("yellow");
        root.green = pick("green");
        root.cyan = pick("cyan");
        root.blue = pick("blue");
        root.magenta = pick("magenta");
        root.bright_red = pick("bright_red");
        root.bright_yellow = pick("bright_yellow");
        root.bright_green = pick("bright_green");
        root.bright_cyan = pick("bright_cyan");
        root.bright_blue = pick("bright_blue");
        root.bright_magenta = pick("bright_magenta");
        root.orange = pick("orange");
        root.brown = pick("brown");
        root.hyprland_active_border = pick("hyprland_active_border");
        root.hyprland_inactive_border = pick("hyprland_inactive_border");
        root.hasPalette = present;
        root.renderPaletteJson = present ? JSON.stringify(palette) : "";
    }
}
