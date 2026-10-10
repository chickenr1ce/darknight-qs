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
    // qsTr("...%1").arg(x) is the repo's label idiom; expose a minimal arg()
    // that follows Qt's rule: each call replaces the lowest-numbered remaining
    // %1..%99 place marker, and only a whole marker (never %1 inside %10).
    vm.runInContext(
        `Object.defineProperty(String.prototype, 'arg', { value: function () {
  let text = String(this);
  for (let i = 0; i < arguments.length; i++) {
    let lowest = 0;
    const scan = /%([0-9]{1,2})/g;
    let match;
    while ((match = scan.exec(text)) !== null) {
      const n = parseInt(match[1], 10);
      if (n >= 1 && (lowest === 0 || n < lowest))
        lowest = n;
    }
    if (lowest === 0)
      break;
    const marker = new RegExp('%' + lowest + '(?![0-9])', 'g');
    text = text.replace(marker, String(arguments[i]));
  }
  return text;
}, writable: true, configurable: true });
globalThis.qmlArg = String.prototype.arg;`,
        ctx
    );
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
