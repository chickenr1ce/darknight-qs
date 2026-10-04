# ADR 0014: audio outputs are discovered, not allowlisted

Date: 2026-10-05. Feature: audio-outputs (`#01`).

## Context

`services/AudioService.qml` held a hardcoded three-entry catalog of the
developer's own hardware:

```qml
readonly property var catalog: [
    { match: "JadeAudio", label: qsTr("JadeAudio JIEZI") },
    { match: "AB13X", label: qsTr("AB13X Dongle") },
    { match: "Pebble", label: qsTr("Creative Pebble V3") }
]
```

Both `sinkNodes` and `sinks` walked the live Pipewire graph but kept only nodes
whose description matched a catalog entry, in catalog order. The catalog did
two jobs at once: filter out "noise" outputs (HDMI, the EasyEffects virtual
sink) and fix a display order. The bar's click-to-cycle used the same list.

The bar's own volume readout reads `Pipewire.defaultAudioSink` directly, so the
only casualties were the dashboard volume list (`windows/DashboardVolumeBlock.qml`
binds `AudioService.sinks`, so it rendered the `"No outputs"` fallback) and the
cycle (which silently did nothing on hardware that matched nothing). A user who
downloads the shell has none of those three devices, so the dashboard is empty
out of the box.

## Decision

Outputs are discovered from Pipewire at runtime and curated by the user.

- `AudioService.discoveredSinkNodes` keeps every node that is a real sink
  (`isSink`, not `isStream`, `audio` non-null), in whatever order Pipewire
  reports.
- `AudioService.sinkNodes` applies a saved order: keys the user has ordered come
  first in that order, then every unseen output sorted by label. A fresh install
  is therefore deterministic and a new device lands in a predictable slot.
- `AudioService.sinks` drops hidden keys and carries `{node, key, label,
  isDefault}` for the dashboard list and the bar cycle. Both read this one list,
  so they cannot disagree.
- The stable key is the Pipewire node `name` (e.g.
  `alsa_output.usb-Creative_Pebble_V3-00.analog-stereo`). `description` and
  `nickname` are human text that can repeat; `id` lives only for one session.
  `keyFor` falls back to `description`, then `nickname`, then `id`.
- The display label is the node `description`, `nickname`, or `name`.
- Curation is `hiddenKeys` and `orderKeys`, persisted to the `audio-outputs`
  state file through `StateFile`, parsed by `StateParsers.parseAudioSettings`,
  and saved behind the loading/loaded guard the other services use.
- `modules/Audio.qml` cycles `AudioService.sinks` and sets the default with
  `wpctl set-default <node.id>`, so the cycle and the dashboard share one order.
- Settings gains an Audio section (`windows/AudioSettingsView.qml`) listing every
  detected output with a show/hide toggle and reorder arrows, filtered through
  the shared `SettingsFilter` and registered in `SettingsService.sections` with
  the `Audio outputs` label plus each output label.

## Alternatives considered

- **Ship an empty catalog and let users edit source.** Blocks `git pull` with a
  dirty tree, exactly the failure ADR 0013 removed for monitors; rejected.
- **Show every sink with no curation.** Fixes the empty dashboard but cannot
  express "hide the EasyEffects sink from my cycle", which the old catalog was
  there to do; rejected in favour of discovery plus curation.
- **Key curation by Pipewire `id`.** The id is transient, so hidden and ordered
  outputs would reset on every restart; rejected.

## Consequences

- A fresh install lists whatever outputs the machine actually has; the
  `"No outputs"` fallback now means nothing is visible, either zero real sinks
  or every output hidden.
- HDMI and virtual sinks appear by default, because hiding them is a per-user
  preference, not a shipping default.
- `audio-outputs` holds `{hidden: [key], order: [key]}`.
- The dashboard list and the bar cycle stay in lockstep; reordering in Settings
  changes both.
