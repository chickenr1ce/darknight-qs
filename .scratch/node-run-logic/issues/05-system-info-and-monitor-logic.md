# 05: SystemInfo and SystemMonitor parsing in node-run JS

**What to build:** `services/SystemLogic.js` holds the fastfetch, `/proc` and
hwmon parsers and the formatters now inline in `SystemInfo.qml` and
`SystemMonitor.qml`; the dashboard-data tests run the real file.

**Blocking:** None

**Blocked by:** 01

**Status:** done

## Origin

Candidate 2 of the 2026-10-07 architecture review. See `../spec.md`. Review
feedback assumed these mirrors cover code bound to QML types. Checked:
`parseFastfetch`, `formatKernel`, `formatShell`, `formatPackages`,
`formatUptime`, `parseCpuSample`, `parseRamPercent`, `parseRamSample`,
`parseTemp`, `parsePercent`, `parseNetSample`, `formatGib` and `formatRate`
are pure string/number functions. Only the `apply*` functions keep
service state, and the delta math inside them can take that state as input.

## Acceptance criteria

- [x] `SystemLogic.js` exports the thirteen functions above unchanged in
      behaviour, plus `cpuPercent(prevTotal, prevIdle, sample)` and
      `netRates(prevRx, prevTx, sample, seconds)` for the delta math now in
      `applyCpuSample` and `applyNetSample`.
- [x] `SystemInfo.qml` and `SystemMonitor.qml` delegate to it and keep their
      public function names; the `apply*` functions still own the property
      writes and the `previous*` bookkeeping.
- [x] The twelve `SystemInfo`/`SystemMonitor` mirrors (five and seven) in
      `test-dashboard-data.sh` become node runs; the Python copies are deleted.
- [x] `scripts/check.sh` passes.
- [ ] Live check: the dashboard system and CPU blocks still show live values.

## Measurement

- [x] `tests/mutation-probe.sh <repo>` reports `caught` for: the `SystemMonitor.parseNetSample` and `SystemInfo.formatPackages` mutants. Retarget a mutant at its new `*Logic.js` file when the function moves; add the test case it needs if the moved mirror cases do not expose it.
- [x] `test-panel-logic.sh` plus `test-dashboard-data.sh` stay under 2.6 s combined (baseline 2.24 s); the commit message records the before and after probe result and timing.
