"use strict";

const fs = require("fs");
const vm = require("vm");

function load(path, globals) {
    // Drop every `.pragma` line, not just the first.
    const src = fs.readFileSync(path, "utf8").replace(/^\.pragma .*$/gm, "");
    // qsTr is a QML global available to any JS loaded in QML, so a real file
    // may call it. This stub covers the single-argument form only; a file that
    // chains qsTr("...%1").arg(x), calls qsTrId/qsTranslate, or uses a QML-JS
    // `.import` directive needs a richer stub.
    const ctx = Object.assign({ console, qsTr: text => text }, globals || {});
    vm.createContext(ctx);
    vm.runInContext(src, ctx, { filename: path });
    return ctx;
}

function canonical(value) {
    if (Array.isArray(value))
        return "[" + value.map(canonical).join(",") + "]";
    if (value !== null && typeof value === "object") {
        const keys = Object.keys(value).sort();
        return "{" + keys.map(key => JSON.stringify(key) + ":" + canonical(value[key])).join(",") + "}";
    }
    if (value === undefined)
        return "undefined";
    return JSON.stringify(value);
}

function equal(a, b) {
    return canonical(a) === canonical(b);
}

function checker(prefix) {
    return function check(name, got, want) {
        if (!equal(got, want)) {
            console.error(prefix + " FAIL: " + name + ": got " + canonical(got) + ", want " + canonical(want));
            process.exit(1);
        }
    };
}

module.exports = { load, equal, checker };
