.pragma library

const THEME_MAX_BYTES = 262144

const CONTROL_CHARS = /[\u0000-\u001f\u007f]/
const CONTROL_CHARS_GLOBAL = /[\u0000-\u001f\u007f]/g

const PALETTE_REQUIRED_KEYS = [
    "accent", "selection", "muted",
    "background", "dark_background", "darker_background", "lighter_background",
    "foreground", "dark_foreground", "light_foreground", "bright_foreground",
    "red", "yellow", "green", "cyan", "blue", "magenta",
    "bright_red", "bright_yellow", "bright_green", "bright_cyan",
    "bright_blue", "bright_magenta"
]

const PALETTE_OPTIONAL_KEYS = [
    "orange", "brown", "hyprland_active_border", "hyprland_inactive_border"
]

const PALETTE_BORDER_KEYS = [
    "hyprland_active_border", "hyprland_inactive_border"
]

function hasControlChars(text) {
    return CONTROL_CHARS.test(text);
}

function displaySafe(text) {
    if (typeof text !== "string")
        return "";
    return text.replace(CONTROL_CHARS_GLOBAL, "");
}

// A theme name is concatenated into a filesystem path and used as a state key,
// so it must be exactly one plain path segment: non-empty, not a dot segment,
// and free of path separators, the catalog field delimiter, the characters a
// URL reads as fragment or query, and control characters.
function isValidThemeName(name) {
    if (typeof name !== "string")
        return false;
    if (name === "" || name === "." || name === "..")
        return false;
    if (name.includes("/") || name.includes("\\") || name.includes("|"))
        return false;
    if (name.includes("#") || name.includes("?"))
        return false;
    return !hasControlChars(name);
}

// Palette values reach QML as colors, where an eight-digit value is #aarrggbb.
// The two optional Hyprland border roles are the exception: they are consumed
// by scripts/render-theme.sh, which reads them as #rrggbbaa. Required roles
// (and orange and brown) are therefore restricted to opaque #rgb or #rrggbb,
// so a theme cannot hand QML an eight-digit value it would read in the wrong
// channel order. The border roles keep the full four-form allowance.
function isColorValue(value) {
    return typeof value === "string"
        && /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(value);
}

function isOpaqueColorValue(value) {
    return typeof value === "string"
        && /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(value);
}

function isValidMode(mode) {
    return mode === "dark" || mode === "light";
}

function themeMaxBytes() {
    return THEME_MAX_BYTES;
}

function parseTomlString(raw) {
    const text = raw.trim();
    if (text.length >= 2 && (text.charAt(0) === '"' || text.charAt(0) === "'")) {
        const end = text.indexOf(text.charAt(0), 1);
        if (end > 0)
            return text.slice(1, end);
    }
    const space = text.search(/\s/);
    return space < 0 ? text : text.slice(0, space);
}

function parseColors(tomlText) {
    if (typeof tomlText !== "string")
        return null;
    const values = {};
    const lines = tomlText.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line === "" || line.charAt(0) === "#" || line.charAt(0) === "[")
            continue;
        const eq = line.indexOf("=");
        if (eq <= 0)
            continue;
        const key = line.slice(0, eq).trim();
        if (!PALETTE_REQUIRED_KEYS.includes(key) && !PALETTE_OPTIONAL_KEYS.includes(key) && key !== "mode")
            continue;
        values[key] = parseTomlString(line.slice(eq + 1));
    }
    const mode = values["mode"];
    if (!isValidMode(mode))
        return null;
    const palette = {};
    for (let i = 0; i < PALETTE_REQUIRED_KEYS.length; i++) {
        const key = PALETTE_REQUIRED_KEYS[i];
        const value = values[key];
        if (!isOpaqueColorValue(value))
            return null;
        palette[key] = value.toLowerCase();
    }
    for (let i = 0; i < PALETTE_OPTIONAL_KEYS.length; i++) {
        const key = PALETTE_OPTIONAL_KEYS[i];
        const valid = PALETTE_BORDER_KEYS.includes(key) ? isColorValue(values[key]) : isOpaqueColorValue(values[key]);
        if (valid)
            palette[key] = values[key].toLowerCase();
    }
    palette["mode"] = mode;
    return palette;
}

function asPlainObject(value) {
    if (!value || typeof value !== "object" || Array.isArray(value))
        return Object.create(null);
    return Object.assign(Object.create(null), value);
}

function isTrustedStat(output) {
    if (typeof output !== "string")
        return false;
    const parts = output.trim().split("|");
    if (parts.length !== 2)
        return false;
    const modeText = parts[0].trim();
    const sizeText = parts[1].trim();
    // stat's %f is hex and %s is decimal; an empty field must fail rather than
    // coerce: Number("") is 0, which would trust a truncated line.
    if (!/^[0-9a-fA-F]+$/.test(modeText) || !/^[0-9]+$/.test(sizeText))
        return false;
    const mode = parseInt(modeText, 16);
    const size = Number(sizeText);
    const fileType = mode & 0xF000;
    return fileType === 0x8000 && size <= THEME_MAX_BYTES;
}

function parseBackgrounds(jsonText) {
    try {
        return asPlainObject(JSON.parse(jsonText));
    } catch (e) {
        return {};
    }
}

const BACKGROUND_SUFFIXES = [".jpg", ".jpeg", ".png", ".webp", ".bmp"]

const BACKGROUND_MAX_BYTES = 33554432

function backgroundMaxBytes() {
    return BACKGROUND_MAX_BYTES;
}

function backgroundName(file) {
    if (typeof file !== "string")
        return "";
    const text = file.trim();
    const slash = Math.max(text.lastIndexOf("/"), text.lastIndexOf("\\"));
    const base = slash >= 0 ? text.slice(slash + 1) : text;
    if (base === "" || base.charAt(0) === "." || base.includes(".."))
        return "";
    if (base.includes("|") || hasControlChars(base))
        return "";
    const dot = base.lastIndexOf(".");
    if (dot <= 0)
        return "";
    if (!BACKGROUND_SUFFIXES.includes(base.slice(dot).toLowerCase()))
        return "";
    return base;
}

function compareBackgroundNames(a, b) {
    if (a.name < b.name)
        return -1;
    if (a.name > b.name)
        return 1;
    return 0;
}

function encodePath(path) {
    if (typeof path !== "string" || path === "")
        return "";
    const parts = path.split("/");
    for (let i = 0; i < parts.length; i++)
        parts[i] = encodeURIComponent(parts[i]);
    return parts.join("/");
}

function parseBackgroundList(output, dir) {
    if (typeof output !== "string")
        return [];
    const base = typeof dir === "string" ? dir : "";
    const entries = [];
    const lines = output.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const name = lines[i];
        if (name === "" || name === "." || name === ".." || name.includes("/"))
            continue;
        if (hasControlChars(name) || backgroundName(name) !== name)
            continue;
        const path = base === "" ? name : base + "/" + name;
        entries.push({
            "name": name,
            "path": path,
            "url": "file://" + encodePath(path)
        });
    }
    entries.sort(compareBackgroundNames);
    return entries;
}

function displayName(name) {
    if (typeof name !== "string")
        return "";
    const words = name.split(/[-_]+/);
    const titled = [];
    for (let i = 0; i < words.length; i++) {
        const word = words[i];
        if (word === "")
            continue;
        titled.push(word.charAt(0).toUpperCase() + word.slice(1));
    }
    return titled.join(" ");
}

function compareCatalogNames(a, b) {
    if (a.displayName < b.displayName)
        return -1;
    if (a.displayName > b.displayName)
        return 1;
    if (a.name < b.name)
        return -1;
    if (a.name > b.name)
        return 1;
    return 0;
}

function parseCatalog(output, themeRoot) {
    if (typeof output !== "string")
        return [];
    const root = typeof themeRoot === "string" ? themeRoot : "";
    const entries = [];
    const lines = output.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line === "")
            continue;
        const sep = line.lastIndexOf("|");
        if (sep <= 0)
            continue;
        const name = line.slice(0, sep);
        const mode = parseTomlString(line.slice(sep + 1));
        if (!isValidMode(mode))
            continue;
        if (!isValidThemeName(name))
            continue;
        entries.push({
            "name": name,
            "displayName": displayName(name),
            "dir": root + "/" + name,
            "mode": mode
        });
    }
    entries.sort(compareCatalogNames);
    return entries;
}

function parseSelection(jsonText) {
    let parsed = null;
    try {
        parsed = JSON.parse(jsonText);
    } catch (e) {
        return { "theme": "", "backgrounds": {} };
    }
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
        return { "theme": "", "backgrounds": {} };
    const theme = isValidThemeName(parsed.theme) ? parsed.theme : "";
    return { "theme": theme, "backgrounds": asPlainObject(parsed.backgrounds) };
}

function serializeSelection(theme, backgroundsJson) {
    return JSON.stringify({ "theme": theme, "backgrounds": parseBackgrounds(backgroundsJson) }) + "\n";
}
