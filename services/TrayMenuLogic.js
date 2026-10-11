.pragma library

const BUTTON_CHECK = 1;
const BUTTON_RADIO = 2;
const STATE_CHECKED = 2;

function checkKind(entry) {
    if (entry.buttonType === BUTTON_CHECK)
        return "check";
    if (entry.buttonType === BUTTON_RADIO)
        return "radio";
    return "";
}

function describeEntry(entry, children) {
    if (!entry)
        return null;
    if (entry.isSeparator)
        return { kind: "separator" };
    const text = entry.text ? String(entry.text) : "";
    if (text === "")
        return null;
    const submenu = entry.hasChildren ? tidy((children || []).map(child => describeEntry(child, []))) : [];
    return {
        kind: "item",
        id: text,
        text: text,
        hint: "",
        glyph: "",
        image: entry.icon ? String(entry.icon) : "",
        enabled: entry.enabled !== false,
        danger: false,
        check: checkKind(entry),
        checked: entry.checkState === STATE_CHECKED,
        submenu: submenu,
        entry: entry
    };
}

function tidy(list) {
    const out = [];
    for (let i = 0; i < list.length; i++) {
        const item = list[i];
        if (!item)
            continue;
        if (item.kind === "separator" && (out.length === 0 || out[out.length - 1].kind === "separator"))
            continue;
        out.push(item);
    }
    while (out.length > 0 && out[out.length - 1].kind === "separator")
        out.pop();
    return out;
}

function describe(entries, childLists) {
    const list = entries || [];
    const out = [];
    for (let i = 0; i < list.length; i++)
        out.push(describeEntry(list[i], childLists ? childLists[i] : []));
    return tidy(out);
}
