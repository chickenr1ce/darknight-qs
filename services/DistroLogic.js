.pragma library

const DISTRO_GLYPHS = {
    "arch": "",  // nf-linux-archlinux U+F303
    "cachyos": "",  // nf-linux-cachyos U+F385
    "endeavouros": "",  // nf-linux-endeavour U+F322
    "manjaro": "",  // nf-linux-manjaro U+F312
    "garuda": "",  // nf-linux-garuda U+F337
    "artix": "",  // nf-linux-artix U+F31F
    "arcolinux": "",  // nf-linux-arcolinux U+F346
    "archcraft": "",  // nf-linux-archcraft U+F345
    "archlabs": "",  // nf-linux-archlabs U+F31E
    "parabola": "",  // nf-linux-parabola U+F340
    "hyperbola": "",  // nf-linux-hyperbola U+F33A
    "biglinux": "",  // nf-linux-biglinux U+F347
    "debian": "",  // nf-linux-debian U+F306
    "ubuntu": "",  // nf-linux-ubuntu U+F31B
    "pop": "",  // nf-linux-pop_os U+F32A
    "linuxmint": "",  // nf-linux-linuxmint U+F30E
    "elementary": "",  // nf-linux-elementary U+F309
    "zorin": "",  // nf-linux-zorin U+F32F
    "kali": "",  // nf-linux-kali_linux U+F327
    "parrot": "",  // nf-linux-parrot U+F329
    "raspbian": "",  // nf-linux-raspberry_pi U+F315
    "deepin": "",  // nf-linux-deepin U+F321
    "mx": "",  // nf-linux-mxlinux U+F33F
    "devuan": "",  // nf-linux-devuan U+F307
    "tails": "",  // nf-linux-tails U+F343
    "trisquel": "",  // nf-linux-trisquel U+F344
    "postmarketos": "",  // nf-linux-postmarketos U+F374
    "fedora": "",  // nf-linux-fedora U+F30A
    "nobara": "",  // nf-linux-nobara U+F380
    "rhel": "",  // nf-linux-redhat U+F316
    "centos": "",  // nf-linux-centos U+F304
    "rocky": "",  // nf-linux-rocky_linux U+F32B
    "almalinux": "",  // nf-linux-almalinux U+F31D
    "opensuse-tumbleweed": "",  // nf-linux-tumbleweed U+F37D
    "opensuse-leap": "",  // nf-linux-leap U+F37E
    "opensuse": "",  // nf-linux-opensuse U+F314
    "suse": "",  // nf-linux-opensuse U+F314
    "nixos": "",  // nf-linux-nixos U+F313
    "gentoo": "",  // nf-linux-gentoo U+F30D
    "void": "",  // nf-linux-void U+F32E
    "alpine": "",  // nf-linux-alpine U+F300
    "slackware": "",  // nf-linux-slackware U+F318
    "solus": "",  // nf-linux-solus U+F32D
    "guix": "",  // nf-linux-gnu_guix U+F325
    "qubes": "",  // nf-linux-qubesos U+F342
    "mageia": "",  // nf-linux-mageia U+F310
    "openwrt": "",  // nf-linux-openwrt U+F382
    "freebsd": "",  // nf-linux-freebsd U+F30C
    "openbsd": ""  // nf-linux-openbsd U+F328
};

const DISTRO_FALLBACK_GLYPH = "";  // nf-linux-tux U+F31A

function splitTokens(value) {
    const raw = String(value).toLowerCase().split(/\s+/);
    const tokens = [];
    for (let i = 0; i < raw.length; i++) {
        if (raw[i] !== "")
            tokens.push(raw[i]);
    }
    return tokens;
}

function unquote(value) {
    const quote = value.charAt(0);
    if ((quote !== "\"" && quote !== "'") || value.length < 2 || value.charAt(value.length - 1) !== quote)
        return value;
    const inner = value.substring(1, value.length - 1);
    return quote === "\"" ? inner.replace(/\\([\\"$`])/g, "$1") : inner;
}

function parseOsRelease(text) {
    const out = { id: "", idLike: [], prettyName: "" };
    const lines = String(text).split(/\r?\n/);
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        const eq = line.indexOf("=");
        if (line === "" || line.charAt(0) === "#" || eq <= 0)
            continue;
        const key = line.substring(0, eq).trim();
        const value = unquote(line.substring(eq + 1).trim());
        if (key === "ID")
            out.id = value.toLowerCase();
        else if (key === "ID_LIKE")
            out.idLike = splitTokens(value);
        else if (key === "PRETTY_NAME")
            out.prettyName = value;
    }
    return out;
}

// hasOwnProperty, not `in`: "constructor" would otherwise match Object.prototype.
function hasGlyph(token) {
    return Object.prototype.hasOwnProperty.call(DISTRO_GLYPHS, token);
}

function distroGlyph(id, idLike) {
    const key = String(id || "").trim().toLowerCase();
    if (hasGlyph(key))
        return DISTRO_GLYPHS[key];
    const likes = Array.isArray(idLike) ? idLike : splitTokens(idLike || "");
    for (let i = 0; i < likes.length; i++) {
        const token = String(likes[i]).toLowerCase();
        if (hasGlyph(token))
            return DISTRO_GLYPHS[token];
    }
    return DISTRO_FALLBACK_GLYPH;
}
