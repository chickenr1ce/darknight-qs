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

    readonly property string defaultThemeName: "darknight"
    property string activeTheme: ""
    property bool selectionKnown: false
    property bool targetsLoaded: false
    property bool paletteResolved: false
    property var themeTargetEnabled: ({})
    readonly property var themeTargets: [
        { key: "hyprland", title: qsTr("Hyprland borders") },
        { key: "kitty", title: qsTr("kitty") },
        { key: "hyprlock", title: qsTr("hyprlock") },
        { key: "starship", title: qsTr("starship") },
        { key: "yazi", title: qsTr("yazi") },
        { key: "btop", title: qsTr("btop") },
        { key: "firefox", title: qsTr("Firefox") },
        { key: "vencord", title: qsTr("Vencord") },
        { key: "spicetify", title: qsTr("Spicetify") }
    ]
    readonly property string enabledThemeTargetKeys: {
        const keys = [];
        for (let i = 0; i < root.themeTargets.length; i++) {
            const key = root.themeTargets[i].key;
            if (root.isThemeTargetEnabled(key))
                keys.push(key);
        }
        return keys.join(",");
    }
    readonly property string activeDisplayName: root.catalogDisplayName(root.activeTheme)

    readonly property string catalogScriptPath: Quickshell.shellDir + "/scripts/theme-catalog-scan.sh"
    readonly property string renderScriptPath: Quickshell.shellDir + "/scripts/render-theme.sh"
    property string catalogText: ""
    property bool catalogReady: false
    property string renderPaletteJson: ""
    readonly property var catalog: ThemeParsers.parseCatalog(root.catalogText, root.themeRoot)
    readonly property var backgroundList: idBackground.list
    readonly property string currentBackgroundName: idBackground.currentName

    property bool colorsTrusted: false
    property string statPath: ""

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
        idBackground.refresh(root.backgroundDirFor(root.activeTheme));
        root.reloadPalette();
        root.saveSelection();
    }
    onThemeTargetEnabledChanged: {
        root.saveTargets();
        Qt.callLater(root.renderDesktop);
    }
    onRenderPaletteJsonChanged: {
        root.paletteResolved = true;
        Qt.callLater(root.renderDesktop);
    }
    Component.onCompleted: root.refresh()

    StateFile {
        id: idThemeState

        name: "theme"
        createDir: true
        onParsed: text => root.applySelection(text)
        onLoadedChanged: Qt.callLater(root.applyDefaultTheme)
    }

    StateFile {
        id: idTargetsState

        name: "theme-targets"
        createDir: true
        onParsed: text => root.applyTargets(text)
        onLoadedChanged: root.resolveTargetsLoaded()
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
                root.applyDefaultTheme();
                if (root.catalogReady && root.activeTheme === "")
                    root.markPaletteResolved();
                if (root.activeTheme !== "" && root.hasPalette && root.effectiveMode("") !== root.mode)
                    root.applyPalette(ThemeParsers.parseColors(idPaletteFile.text(), root.catalogMode(root.activeTheme)));
            }
        }
        onExited: code => idCatalogRun.finished(code === 0)
    }

    CoalescedRun {
        id: idCatalogRun

        process: idCatalogProcess

        starter: () => {
            idCatalogProcess.running = true;
        }
    }

    Process {
        id: idStatProcess

        command: ["stat", "-c", "%f|%s", root.colorsPath]
        stdout: idStatCollector
        onExited: code => idStatRun.finished(code === 0)
    }

    CoalescedRun {
        id: idStatRun

        process: idStatProcess

        // A drain bypasses statPalette, so it re-checks the precondition
        // itself: a theme reset emptied colorsPath since the request queued.
        starter: path => {
            if (root.colorsPath === "")
                return false;
            root.statPath = path;
            idStatProcess.running = true;
        }
    }

    Process {
        id: idRenderProcess

        command: ["sh", root.renderScriptPath, root.renderPaletteJson, root.enabledThemeTargetKeys]
        onExited: code => {
            if (code !== 0)
                console.warn("ThemeService: render-theme.sh exited non-zero (" + code + ")");
            idRenderRun.finished(code === 0);
        }
    }

    CoalescedRun {
        id: idRenderRun

        process: idRenderProcess

        // A drain bypasses renderDesktop, so it re-checks the preconditions
        // itself, like the old Qt.callLater(renderDesktop) drain did.
        starter: () => {
            if (!root.paletteResolved || !root.targetsLoaded)
                return false;
            idRenderProcess.running = true;
            idBackground.applyCurrent();
        }
    }

    ThemeBackground {
        id: idBackground

        theme: root.activeTheme
        dir: root.backgroundDirFor(root.activeTheme)
        onMemoryJsonChanged: root.saveSelection()
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
        onLoaded: {
            root.applyPalette(ThemeParsers.parseColors(idPaletteFile.text(), root.catalogMode(root.activeTheme)));
            root.markPaletteResolved();
        }
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
        root.selectionKnown = ThemeParsers.isSelectionObject(jsonText);
        const hadTheme = root.activeTheme !== "";
        idBackground.memoryJson = JSON.stringify(selection.backgrounds);
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

    function applyDefaultTheme(): void {
        if (!idThemeState.loaded || root.selectionKnown)
            return;
        if (root.activeTheme !== "" || !root.hasTheme(root.defaultThemeName))
            return;
        root.selectTheme(root.defaultThemeName);
    }

    function saveSelection(): void {
        idThemeState.save(ThemeParsers.serializeSelection(root.activeTheme, idBackground.memoryJson));
    }

    function refresh(): void {
        idBackground.refresh(root.backgroundDirFor(root.activeTheme));
        idCatalogRun.request();
    }

    function catalogDisplayName(name: string): string {
        const entry = root.catalogEntry(name);
        return entry ? entry.displayName : "";
    }

    function catalogMode(name: string): string {
        const entry = root.catalogEntry(name);
        return entry && (entry.mode === "light" || entry.mode === "dark") ? entry.mode : "";
    }

    // The scan resolves mode through the `light.mode` marker and luminance,
    // which the parser cannot see. Prefer it once the catalog has an entry.
    function effectiveMode(fallback: string): string {
        const fromCatalog = root.catalogMode(root.activeTheme);
        return fromCatalog !== "" ? fromCatalog : fallback;
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

    function hasThemeTarget(key: string): bool {
        for (let i = 0; i < root.themeTargets.length; i++) {
            if (root.themeTargets[i].key === key)
                return true;
        }
        return false;
    }

    function isThemeTargetEnabled(key: string): bool {
        return !(root.themeTargetEnabled[key] === false);
    }

    function sameTargets(a, b): bool {
        for (let i = 0; i < root.themeTargets.length; i++) {
            const key = root.themeTargets[i].key;
            if (!(a[key] === b[key]))
                return false;
        }
        return true;
    }

    function themeTargetKeys(): var {
        const keys = [];
        for (let i = 0; i < root.themeTargets.length; i++)
            keys.push(root.themeTargets[i].key);
        return keys;
    }

    function parseTargets(jsonText: string): var {
        return ThemeParsers.parseTargets(jsonText, root.themeTargetKeys());
    }

    function serializeTargets(map): string {
        return ThemeParsers.serializeTargets(map, root.themeTargetKeys());
    }

    function applyTargets(jsonText: string): void {
        const next = root.parseTargets(jsonText);
        if (root.sameTargets(root.themeTargetEnabled, next))
            return;
        root.themeTargetEnabled = next;
    }

    function saveTargets(): void {
        idTargetsState.save(root.serializeTargets(root.themeTargetEnabled));
    }

    function setThemeTargetEnabled(key: string, enabled: bool): void {
        if (!root.hasThemeTarget(key) || root.isThemeTargetEnabled(key) === enabled)
            return;
        const next = {};
        for (let i = 0; i < root.themeTargets.length; i++) {
            const targetKey = root.themeTargets[i].key;
            next[targetKey] = targetKey === key ? enabled : root.isThemeTargetEnabled(targetKey);
        }
        root.themeTargetEnabled = next;
    }

    function resolveTargetsLoaded(): void {
        if (root.targetsLoaded)
            return;
        root.targetsLoaded = true;
        Qt.callLater(root.renderDesktop);
    }

    function markPaletteResolved(): void {
        root.paletteResolved = true;
        Qt.callLater(root.renderDesktop);
    }

    function renderDesktop(): void {
        if (!root.paletteResolved || !root.targetsLoaded)
            return;
        idRenderRun.request();
    }

    function backgroundDirFor(theme: string): string {
        if (!root.themePathAllowed(theme))
            return "";
        return root.themeRoot + "/" + theme + "/backgrounds";
    }

    function selectBackground(file: string): string {
        return idBackground.select(file);
    }

    function reloadPalette(): void {
        root.colorsTrusted = false;
        root.applyPalette(null);
        if (root.activeTheme === "") {
            root.markPaletteResolved();
            return;
        }
        Qt.callLater(root.statPalette);
    }

    function paletteLoadFailed(): void {
        root.colorsTrusted = false;
        root.applyPalette(null);
        root.markPaletteResolved();
    }

    function statPalette(): void {
        if (root.colorsPath === "")
            return;
        idStatRun.request(root.colorsPath);
    }

    function applyStat(output: string): void {
        if (root.statPath === root.colorsPath && ThemeParsers.isTrustedStat(output)) {
            root.colorsTrusted = true;
        } else {
            root.colorsTrusted = false;
            root.applyPalette(null);
            root.markPaletteResolved();
        }
    }

    function applyPalette(palette): void {
        const present = palette !== null && palette !== undefined;
        const mode = present ? root.effectiveMode(palette.mode) : "";
        if (present)
            palette.mode = mode;
        const pick = key => present && palette[key] !== undefined ? palette[key] : root.fallbackColor;
        root.mode = mode;
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
