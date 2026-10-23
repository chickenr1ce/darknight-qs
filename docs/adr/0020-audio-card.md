# ADR 0020: the audio card is a floating panel and WirePlumber saves its choices

Date: 2026-10-14. Feature: audio card (ticket 04).

## Context

Right-clicking the bar's audio module launched `pavucontrol`
(`modules/Audio.qml` `openMixer()`): an unthemed window for three everyday jobs,
picking the output, picking the microphone, and setting per-app volume. The
shell had no input (source) handling and no per-app volume.

Design plan 14 (`docs/plans/archive/14-audio-window-designs.html`) explored four themed
replacements: the stacked sheet, a mixer board with one channel strip per node,
a tabbed popover, and routing lanes that drew the stream graph.

## Decision

The audio card is a floating quick panel, `windows/AudioCenter.qml`, opened by
right-clicking the bar's audio module. It has three stacked sections, Output,
Input, and Apps. Its rows compose `components/VolumeControl.qml`, driven by the
`PwNode` each row shows.

- **Variant 1, the stacked sheet.** Chosen over the mixer board (2), the tabbed
  popover (3), and routing lanes (4). One vertical list per section works at
  any stream count, with no horizontal axis to scroll and no tabs to flip, and
  it matches the lists the dashboard and the cava settings already use. The
  board and the lanes also draw per-stream routing, which this feature does
  not offer.
- **Floating, not a bar junction.** The card composes `PanelShell` like the
  calendar and cava cards (ADR 0001): it opens `Globals.panelTopGap` under the
  module, centred and clamped to the screen, with the floating fade. It is not
  attached to the bar with the dashboard's concave junction (ADR 0005). A
  junction joins a card that coexists beside the bar; the audio card is a quick
  panel under the one-panel rule (`services/Panels.qml`), so opening it closes
  the calendar and cava.
- **WirePlumber owns persistence, the shell adds no `StateFile`.** Every choice
  in the card is live PipeWire state that WirePlumber already restores. On this
  machine WirePlumber 0.5.18 (`pacman -Q wireplumber` reports `wireplumber
  0.5.18-1.1`) keeps `~/.local/state/wireplumber/` with `default-nodes`,
  `default-profile`, `default-routes`, and `stream-properties`. `wpctl
  set-default` writes `default-nodes`; device volume and mute are in
  `default-routes`; a per-app volume and mute is in `stream-properties` under a
  key like `Output/Audio:application.name:spotify`. That last file is written
  by the `node.stream.restore-props` setting, default `true` in
  `/usr/share/wireplumber/wireplumber.conf`. The shell writes `node.audio.volume`
  and `node.audio.muted`, sets the default through `wpctl`, keeps no copy, and
  leaves `audio-outputs`, the ADR 0014 curation file, as it was. A
  `StateFile` mirroring WirePlumber would be a second owner of the same values
  and could disagree with `pavucontrol` or `wpctl`; the card reads the live
  graph instead.
- **One writer for the default device.** `services/AudioService.qml` owns
  `setDefaultSink(node)` and `setDefaultSource(node)`, each running `wpctl
  set-default <id>` through its own `CoalescedRun` and `Process`. The bar's
  cycle and the card's dropdowns both call them, so one component picks the
  default. The coalescing key is per kind: sharing one run lost a pick when a
  sink request and a source request landed in the same run, because the later
  id overwrote the pending one.
- **The app-stream filter is an exact `media.class` match.**
  `AudioService.appStreams` holds the nodes whose
  `properties["media.class"]` is exactly `Stream/Output/Audio`, one row per
  stream, sorted by app name then node id. The exact match needs no special
  case to exclude the EasyEffects internals (the `ee_soe_*` nodes have an empty
  `media.class`) or cava (a `Stream/Input/Audio` capture stream), and it keeps a
  virtual sink out of the list.
- **The peak monitor runs only while the card is open.** The Input meter's
  `PwNodePeakMonitor` has `enabled: AudioService.panelState.visible`, so the
  shell creates no capture stream while the card is closed.
- **Quickshell 0.3.1 facts that shaped the code.** A node's `properties` map is
  empty until the node is bound, so `AudioService` binds every node in
  `Pipewire.nodes` with one `PwObjectTracker`; discovery (`media.class`) and the
  "in use by" list would otherwise read nothing. A virtual source such as Easy
  Effects Source carries the `Audio/Source/Virtual` media class and a null
  `audio`, so it is listed as an input while its volume row stays laid out and
  disabled.
- **The pavucontrol button stays.** The header's `Icons.openExternal`
  `IconButton` launches `pavucontrol` detached and closes the card, so the
  advanced mixer is one click away.

## Alternatives considered

- **The mixer board, the tabbed popover, and routing lanes (variants 2 to 4).**
  More structure for the same three jobs, and the board and the lanes imply
  per-stream routing the card does not do; rejected for the stacked sheet.
- **Attaching the card to the bar with a junction (ADR 0005).** The junction
  suits the persistent dashboard, which opens beside a quick panel; the audio
  card is itself a quick panel and must close the others; rejected.
- **Keeping `pavucontrol` as the only mixer.** It is unthemed, separate, and
  has no bar anchor; rejected.
- **A shell `StateFile` for the card's values.** WirePlumber already writes
  them, so a second copy would fight `pavucontrol` and `wpctl`; rejected.

## Consequences

- Settings made in the card survive an audio-stack restart and a reboot through
  WirePlumber, and the shell writes no file for them.
- Apps play into `easyeffects_sink` when EasyEffects is active, so changing the
  default output changes where EasyEffects plays, not where each app sends its
  stream. That is expected and the card does not move streams.
- Two Firefox tabs appear as two rows; the card does not group streams of one
  app.
- The card is a quick panel, so it closes the calendar and cava when it opens
  and stores nothing beside them.
- The user page is `docs/user/audio.md`; the `audio` target is in
  `docs/user/ipc.md`.
