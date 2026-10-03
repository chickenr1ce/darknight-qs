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

const ANSI_KEYS = [
    "color0", "color1", "color2", "color3", "color4", "color5", "color6", "color7",
    "color8", "color9", "color10", "color11", "color12", "color13", "color14", "color15"
];

// Legacy short names mapped onto their canonical v4 role.
const LEGACY_SHORT_NAMES = {
    "background": "bg",
    "dark_background": "dark_bg",
    "darker_background": "darker_bg",
    "lighter_background": "lighter_bg",
    "foreground": "fg",
    "dark_foreground": "dark_fg",
    "light_foreground": "light_fg",
    "bright_foreground": "bright_fg"
};

const LEGACY_COLOR_KEYS = [
    "bg", "dark_bg", "darker_bg", "lighter_bg",
    "fg", "dark_fg", "light_fg", "bright_fg"
];

// ANSI slots mapped onto the semantic roles, mirroring omarchy-theme-color.
const ANSI_ROLES = {
    "red": "color1",
    "green": "color2",
    "yellow": "color3",
    "blue": "color4",
    "magenta": "color5",
    "cyan": "color6",
    "bright_red": "color9",
    "bright_green": "color10",
    "bright_yellow": "color11",
    "bright_blue": "color12",
    "bright_magenta": "color13",
    "bright_cyan": "color14"
};

const COLOR_KEYS = PALETTE_REQUIRED_KEYS.concat(
    PALETTE_OPTIONAL_KEYS,
    ["selection_background", "selection_foreground", "cursor", "purple", "bright_purple"],
    ANSI_KEYS,
    LEGACY_COLOR_KEYS
);

function hexPair(value, index) {
    return parseInt(value.slice(index, index + 2), 16);
}

function toHex(r, g, b) {
    const clamp = c => Math.max(0, Math.min(255, c));
    const pair = c => clamp(c).toString(16).padStart(2, "0");
    return "#" + pair(r) + pair(g) + pair(b);
}

// Normalize a palette value to lowercase `#rrggbb` or `#rrggbbaa`; an empty
// string means the value is not a hex color. Short forms expand so an ANSI
// source is comparable to a canonical key.
function normalizeColor(value) {
    const text = typeof value === "string" ? value.trim() : "";
    let match = /^#([0-9a-fA-F]{3})$/.exec(text);
    if (match) {
        const h = match[1];
        return ("#" + h[0] + h[0] + h[1] + h[1] + h[2] + h[2]).toLowerCase();
    }
    match = /^#([0-9a-fA-F]{4})$/.exec(text);
    if (match) {
        const h = match[1];
        return ("#" + h[0] + h[0] + h[1] + h[1] + h[2] + h[2] + h[3] + h[3]).toLowerCase();
    }
    if (/^#[0-9a-fA-F]{6}$/.test(text) || /^#[0-9a-fA-F]{8}$/.test(text))
        return text.toLowerCase();
    return "";
}

function rgbOf(hex) {
    const h = hex.replace("#", "");
    return [hexPair(h, 0), hexPair(h, 2), hexPair(h, 4)];
}

// omarchy's mix: int(a*(1-t) + b*t + 0.5) per channel.
function mixColor(start, end, amount) {
    const a = normalizeColor(start);
    const b = normalizeColor(end);
    if (a === "" || b === "")
        return "";
    const from = rgbOf(a);
    const to = rgbOf(b);
    const t = Math.max(0, Math.min(1, amount));
    const channel = (x, y) => Math.floor(x * (1 - t) + y * t + 0.5);
    return toHex(channel(from[0], to[0]), channel(from[1], to[1]), channel(from[2], to[2]));
}

// omarchy resolves light/dark from a six-digit #rrggbb background (382 is the
// midpoint of three 255-wide channels); any other form is dark. There is no
// `dark.mode` marker: dark is the default.
function luminanceMode(background) {
    if (typeof background !== "string" || !/^#[0-9a-fA-F]{6}$/.test(background))
        return "dark";
    const rgb = rgbOf(background.toLowerCase());
    return rgb[0] + rgb[1] + rgb[2] > 382 ? "light" : "dark";
}

function resolveMode(declared, modeHint, backgroundRaw) {
    if (isValidMode(declared["mode"]))
        return declared["mode"];
    if (isValidMode(declared["theme_type"]))
        return declared["theme_type"];
    if (isValidMode(modeHint))
        return modeHint;
    return luminanceMode(backgroundRaw);
}

// Resolve a colors.toml into the guaranteed v4 palette. A canonical file
// resolves to itself; a pre-semantic file (ANSI color0-color15 plus a few named
// roles) is filled in through omarchy-theme-color's cascade, so a theme omarchy
// v4 reads is a theme this shell reads. `modeHint`, when given, is the mode the
// catalog scan resolved (including the `light.mode` marker the parser cannot
// see) and takes precedence over a background's luminance.
function parseColors(tomlText, modeHint) {
    if (typeof tomlText !== "string")
        return null;
    const colors = {};
    const rawColors = {};
    const declared = {};
    const lines = tomlText.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line === "" || line.charAt(0) === "#" || line.charAt(0) === "[")
            continue;
        const eq = line.indexOf("=");
        if (eq <= 0)
            continue;
        const key = line.slice(0, eq).trim();
        const decoded = parseTomlString(line.slice(eq + 1));
        if (key === "mode" || key === "theme_type") {
            declared[key] = decoded;
            continue;
        }
        if (!COLOR_KEYS.includes(key))
            continue;
        rawColors[key] = decoded;
        const value = normalizeColor(decoded);
        if (value !== "")
            colors[key] = value;
    }

    for (const canonical in LEGACY_SHORT_NAMES) {
        const legacy = LEGACY_SHORT_NAMES[canonical];
        if (colors[canonical] === undefined && colors[legacy] !== undefined)
            colors[canonical] = colors[legacy];
    }
    if (colors["background"] === undefined && colors["color0"] !== undefined)
        colors["background"] = colors["color0"];
    if (colors["foreground"] === undefined && colors["color7"] !== undefined)
        colors["foreground"] = colors["color7"];
    // omarchy overwrites color0/color7 from the semantic key when it exists, so
    // derived roles read the canonical value rather than a stale ANSI slot.
    if (colors["background"] !== undefined)
        colors["color0"] = colors["background"];
    if (colors["foreground"] !== undefined)
        colors["color7"] = colors["foreground"];
    for (const role in ANSI_ROLES) {
        const ansi = ANSI_ROLES[role];
        if (colors[role] === undefined && colors[ansi] !== undefined)
            colors[role] = colors[ansi];
    }
    if (colors["magenta"] === undefined && colors["purple"] !== undefined)
        colors["magenta"] = colors["purple"];
    if (colors["bright_magenta"] === undefined && colors["bright_purple"] !== undefined)
        colors["bright_magenta"] = colors["bright_purple"];
    if (colors["light_foreground"] === undefined)
        colors["light_foreground"] = colors["color7"] || colors["foreground"];
    if (colors["bright_foreground"] === undefined)
        colors["bright_foreground"] = colors["color15"] || colors["foreground"];
    colors["cursor"] = colors["bright_foreground"];
    if (colors["lighter_background"] === undefined)
        colors["lighter_background"] = colors["color0"] || colors["background"];
    if (colors["dark_foreground"] === undefined)
        colors["dark_foreground"] = colors["color8"] || colors["foreground"];
    if (colors["muted"] === undefined)
        colors["muted"] = colors["color8"] || colors["dark_foreground"];
    if (colors["selection"] === undefined)
        colors["selection"] = colors["selection_background"] || colors["color8"]
            || colors["color0"] || colors["background"];
    if (colors["selection_background"] === undefined)
        colors["selection_background"] = colors["selection"];
    if (colors["selection_foreground"] === undefined)
        colors["selection_foreground"] = colors["bright_foreground"];
    if (colors["orange"] === undefined)
        colors["orange"] = colors["yellow"];
    if (colors["brown"] === undefined)
        colors["brown"] = mixColor(colors["orange"], "#000000", 0.5);
    if (colors["dark_background"] === undefined)
        colors["dark_background"] = mixColor(colors["background"], "#000000", 0.25);
    if (colors["darker_background"] === undefined)
        colors["darker_background"] = mixColor(colors["background"], "#000000", 0.5);
    if (colors["bright_red"] === undefined)
        colors["bright_red"] = mixColor(colors["red"], "#ffffff", 0.2);
    if (colors["bright_yellow"] === undefined)
        colors["bright_yellow"] = mixColor(colors["yellow"], "#ffffff", 0.2);
    if (colors["bright_green"] === undefined)
        colors["bright_green"] = mixColor(colors["green"], "#ffffff", 0.2);
    if (colors["bright_cyan"] === undefined)
        colors["bright_cyan"] = mixColor(colors["cyan"], "#ffffff", 0.2);
    if (colors["bright_blue"] === undefined)
        colors["bright_blue"] = mixColor(colors["blue"], "#ffffff", 0.2);
    if (colors["bright_magenta"] === undefined)
        colors["bright_magenta"] = mixColor(colors["magenta"], "#ffffff", 0.2);

    const palette = {};
    for (let i = 0; i < PALETTE_REQUIRED_KEYS.length; i++) {
        const key = PALETTE_REQUIRED_KEYS[i];
        const value = colors[key];
        if (!isOpaqueColorValue(value))
            return null;
        palette[key] = value.toLowerCase();
    }
    for (let i = 0; i < PALETTE_OPTIONAL_KEYS.length; i++) {
        const key = PALETTE_OPTIONAL_KEYS[i];
        const value = colors[key];
        const valid = PALETTE_BORDER_KEYS.includes(key) ? isColorValue(value) : isOpaqueColorValue(value);
        if (valid)
            palette[key] = value.toLowerCase();
    }
    let backgroundRaw = rawColors["background"];
    if (backgroundRaw === undefined)
        backgroundRaw = rawColors["bg"];
    if (backgroundRaw === undefined)
        backgroundRaw = rawColors["color0"];
    palette["mode"] = resolveMode(declared, modeHint, backgroundRaw);
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
