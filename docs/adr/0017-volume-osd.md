# ADR 0017: the volume OSD is event-driven from PipeWire

Date: 2026-10-08. Feature: volume-osd (`#05a`).

## Context

Volume can change from many places: the bar's scroll wheel, media keys,
`wpctl set-volume`, `pavucontrol`, or `quickshell ipc call volume up`. The bar
already renders the live volume, but a change made outside the bar gets no
feedback — there is no transient readout.

The shell has one existing transient layer, `windows/NotificationPopups.qml`: a
`PanelWindow` on the primary screen, `exclusionMode: ExclusionMode.Ignore`, a
fixed canvas plus an input `mask` `Region`, hidden while idle. A volume OSD has
the same shape but different placement (bottom-center, on the focused monitor)
and a different lifetime (a short hold after the last change).

The trigger must not be the `volume` IPC handler: `wpctl`, `pavucontrol`, and
media keys never call it, so an IPC-driven OSD would miss most real changes.
PipeWire property changes are the only source that sees every path.

## Decision

The OSD is a `PanelWindow` (`windows/VolumeOsd.qml`) that reacts to the default
sink's PipeWire properties.

- **Event-driven, not IPC-driven.** A `Connections` targets
  `AudioService.defaultSink ? AudioService.defaultSink.audio : null` and handles
  `onVolumesChanged` and `onMutedChanged`. These are the declared NOTIFY signals
  of the properties the OSD reads: `PwNodeAudio.volume` notifies through
  `volumesChanged` (there is no `volumeChanged`) and `PwNodeAudio.muted` through
  `mutedChanged` (verified against the installed 0.3.1
  `quickshell-service-pipewire.qmltypes`). Any writer that touches the sink
  raises the OSD; the `volume` IPC handler is not involved.
- **Bottom-center on the focused monitor.** The window anchors only to
  `bottom` with `Globals.osdBottomMargin`; wlr-layer-shell centers an unanchored
  axis, so the compositor places the surface bottom-center. `MonitorService.focusedScreen()` (which
  falls back to the primary) is captured on the hidden -> shown transition only,
  so a focus change while the OSD is up does not move it.
- **Click-through.** `mask: Region {}` keeps the input region empty, so the OSD
  never steals a click.
- **Content.** A `Card` holds an `Icon` (`Icons.volumeOff` with no sink audio,
  `Icons.volumeMute` muted, else `Icons.volumeHigh`, matching `modules/Audio.qml`),
  a level bar filled to `min(volume, 1)` and dimmed while muted, and the raw
  rounded percent (`AudioLogic.percentText`, so an amplified 120% reads `120%`).
  The percent label reserves width with a `TextMetrics` on `"150%"`, so the
  layout never reflows as the number changes.
- **Timing.** Each change restarts a `Globals.osdHoldMs` hide timer (1400ms).
  The fade uses `Globals.reducedMotion ? 0 : Globals.toastMs`; the window stays
  `visible` through the fade (`shown || fading`) so the fade is seen, then hides.
- **Arm guard.** Changes within `Globals.osdArmMs` (500ms) of startup or of a
  `AudioService.defaultSink` change are ignored, so boot and output switching do
  not flash the OSD.

## Alternatives considered

- **Raise the OSD from the `volume` IPC handler.** Misses `wpctl`,
  `pavucontrol`, and media keys, which are the common paths; rejected.
- **A `Variants` window per screen (one OSD per monitor).** The readout is one
  short message for the monitor the person is looking at; running hidden OSDs on
  every output costs a layer surface each and still needs a focus rule to pick
  one; rejected in favour of one window whose screen is captured per show.
- **Show on all monitors at once.** Same cost and it duplicates a single
  transient message across outputs; rejected.
- **A `FloatingWindow`.** Needs compositor window rules and manages input focus;
  a panel window with an empty mask is click-through by construction; rejected.

## Consequences

- Every volume or mute change, whatever wrote it, shows the OSD for
  `Globals.osdHoldMs`; repeated changes keep it up and reset the hold.
- The OSD is on by default; Settings → Audio → "Volume OSD" turns it off
  (`AudioService.osdEnabled`, persisted in the audio settings state file).
- The OSD lives in the shell process and places itself through the same layer
  protocol as the bar and toasts, so it inherits the theme and reduced motion.
- `services/AudioLogic.js` gains `percentText` (used by `statusText` too) and
  `volumeFraction`, covered by the node tests in `scripts/test-dashboard-data.sh`.
