#!/usr/bin/env bash
# Headless gate for the pure background decisions now in services/ThemeParsers.js:
# entry lookup, remembered/current name resolution, selection (message, memory
# JSON, and path), and the apply/retry/scan predicates, run for real under node
# through tests/qmljs.js so a broken function fails here, not in the shell.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "theme-background FAIL: $*" >&2; exit 1; }

node - "$ROOT/tests/qmljs.js" "$ROOT/services/ThemeParsers.js" <<'NODEEOF' || fail "the background decisions failed their node checks"
const qmljs = require(process.argv[2]);
const check = qmljs.checker('theme-background');
const tp = qmljs.load(process.argv[3]);

for (const fn of ['backgroundEntry', 'currentBackgroundName', 'rememberedBackground',
                  'selectBackground', 'backgroundApplyNeeded', 'backgroundApplyRetries',
                  'backgroundScanCurrent']) {
    if (typeof tp[fn] !== 'function') {
        console.error('theme-background FAIL: ThemeParsers.js does not expose ' + fn);
        process.exit(1);
    }
}

// The fixture follows the shipped parser: two sorted entries under a theme dir.
const ENTRIES = tp.parseBackgroundList("one.png\ntwo.png\n", "/t/backgrounds");
check('fixture/order', ENTRIES.map(e => e.name), ['one.png', 'two.png']);
check('fixture/path', ENTRIES[1].path, '/t/backgrounds/two.png');

check('entry/hit', tp.backgroundEntry(ENTRIES, 'two.png'), ENTRIES[1]);
check('entry/hit-name', tp.backgroundEntry(ENTRIES, 'one.png').name, 'one.png');
check('entry/miss', tp.backgroundEntry(ENTRIES, 'three.png'), null);
check('entry/non-array', tp.backgroundEntry('one.png', 'one.png'), null);
check('entry/undefined-entries', tp.backgroundEntry(undefined, 'one.png'), null);

check('current/remembered', tp.currentBackgroundName(ENTRIES, 'two.png'), 'two.png');
check('current/remembered-missing-first', tp.currentBackgroundName(ENTRIES, 'gone.png'), 'one.png');
check('current/empty-remembered-first', tp.currentBackgroundName(ENTRIES, ''), 'one.png');
check('current/empty-list', tp.currentBackgroundName([], 'two.png'), '');
check('current/non-array', tp.currentBackgroundName(null, 'two.png'), '');

check('remembered/string', tp.rememberedBackground('{"t":"two.png"}', 't'), 'two.png');
check('remembered/absent', tp.rememberedBackground('{"t":"two.png"}', 'other'), '');
check('remembered/non-string', tp.rememberedBackground('{"t":5}', 't'), '');
check('remembered/corrupt', tp.rememberedBackground('{nope', 't'), '');
check('remembered/proto-key-safety', tp.rememberedBackground('{}', '__proto__'), '');
check('remembered/proto-key-kept', tp.rememberedBackground('{"__proto__":"a.png"}', '__proto__'), 'a.png');

check('select/no-theme', tp.selectBackground('{}', '', 'one.png', ENTRIES),
      { message: 'error: no active theme', memoryJson: '{}', path: '' });
check('select/no-theme-nonstring', tp.selectBackground('{}', null, 'one.png', ENTRIES),
      { message: 'error: no active theme', memoryJson: '{}', path: '' });
// backgroundName takes the basename, so a traversal path resolves to a plain
// name: an unknown one is refused, and a known one can only reach the entry
// inside the theme directory, never the path the caller typed.
check('select/traversal-unknown-name', tp.selectBackground('{}', 't', '../x.png', ENTRIES),
      { message: 'error: no background named x.png in this theme', memoryJson: '{}', path: '' });
check('select/traversal-stays-in-theme', tp.selectBackground('{}', 't', '../two.png', ENTRIES).path,
      '/t/backgrounds/two.png');
check('select/not-an-image', tp.selectBackground('{}', 't', 'notes.txt', ENTRIES),
      { message: 'error: not a background image: notes.txt', memoryJson: '{}', path: '' });
check('select/dotfile-not-an-image', tp.selectBackground('{}', 't', '.hidden.png', ENTRIES),
      { message: 'error: not a background image: .hidden.png', memoryJson: '{}', path: '' });
check('select/no-extension', tp.selectBackground('{}', 't', 'plain', ENTRIES),
      { message: 'error: not a background image: plain', memoryJson: '{}', path: '' });
check('select/control-chars-stripped', tp.selectBackground('{}', 't', 'three\u0001x.png', ENTRIES),
      { message: 'error: not a background image: threex.png', memoryJson: '{}', path: '' });
check('select/unknown-name', tp.selectBackground('{}', 't', 'three.png', ENTRIES),
      { message: 'error: no background named three.png in this theme', memoryJson: '{}', path: '' });

const picked = tp.selectBackground('{"t":"one.png","other":"keep.png"}', 't', 'two.png', ENTRIES);
check('select/ok-message', picked.message, 'ok: two.png');
check('select/ok-path', picked.path, '/t/backgrounds/two.png');
check('select/ok-memory', JSON.parse(picked.memoryJson), { t: 'two.png', other: 'keep.png' });
check('select/ok-memory-empty-input', JSON.parse(tp.selectBackground('', 't', 'one.png', ENTRIES).memoryJson),
      { t: 'one.png' });
check('select/ok-full-path', tp.selectBackground('{}', 't', '/a/b/two.png', ENTRIES).message, 'ok: two.png');
check('select/ok-full-path-resolves', tp.selectBackground('{}', 't', '/a/b/two.png', ENTRIES).path,
      '/t/backgrounds/two.png');

check('apply-needed/different', tp.backgroundApplyNeeded('/t/backgrounds/two.png', '/t/backgrounds/one.png'), true);
check('apply-needed/same', tp.backgroundApplyNeeded('/t/backgrounds/one.png', '/t/backgrounds/one.png'), false);
check('apply-needed/empty', tp.backgroundApplyNeeded('', ''), false);
check('apply-needed/empty-applied', tp.backgroundApplyNeeded('', '/x'), false);
check('apply-needed/nonstring', tp.backgroundApplyNeeded(null, ''), false);

check('retries/ok', tp.backgroundApplyRetries(true, '/t/backgrounds/one.png'), false);
check('retries/ok-empty-list', tp.backgroundApplyRetries(true, ''), false);
check('retries/empty-list', tp.backgroundApplyRetries(false, ''), false);
check('retries/failed-with-path', tp.backgroundApplyRetries(false, '/t/backgrounds/one.png'), true);

check('scan/match', tp.backgroundScanCurrent('/t/backgrounds', '/t/backgrounds'), true);
check('scan/mismatch', tp.backgroundScanCurrent('/t/backgrounds', '/t/other'), false);
check('scan/empty-current', tp.backgroundScanCurrent('/t/backgrounds', ''), false);
check('scan/empty-scan', tp.backgroundScanCurrent('', ''), false);
check('scan/empty-scan-nonempty-current', tp.backgroundScanCurrent('', '/t/backgrounds'), false);
NODEEOF

echo "theme-background: all ok"
