# Audio card

Right-click the bar's audio module to open the audio card under it. The card is
a themed replacement for `pavucontrol` for the everyday jobs: picking the
output, picking the microphone, and setting per-app volume. Every change is
live PipeWire state, so it takes effect at once.

## What the card shows

### Output

A dropdown of the outputs, the same list as the dashboard and the bar's click
cycle, with the current default selected. Picking one makes it the default
output. Below it a volume row holds a mute button, a slider, and the percent
for the default output.

The dropdown follows the curation in Settings → Audio, so an output you hid
there stays hidden here, and the order matches.

### Input

A dropdown of the microphones and other capture sources, including virtual
sources such as Easy Effects Source, with a volume row that uses microphone
glyphs. Under the slider a small meter follows the live level of the default
source. A virtual source has no PipeWire audio object, so its volume row stays
in place but is disabled.

A caption on the section header reads "In use by ..." with the apps currently
recording from the default source, for example Discord or OBS. It is blank when
nothing is recording.

### Apps

One row per playback stream: the app icon, the app name with the stream title
under it (a track or a tab title), a volume slider, the percent, and a mute
button. A muted row dims but stays adjustable. Two Firefox tabs show as two
rows. With nothing playing the section reads "Nothing is playing".

The card caps its height and scrolls the Apps list past the cap; the header,
Output, and Input stay put.

## Mouse and keys

| Input | Result |
| --- | --- |
| Right-click the bar's audio module | Open or close the card. |
| Left-click the module | Cycle to the next output. |
| Wheel over the module | Step the default output volume. |
| Drag a slider, or click a mute button | Change that node. |
| Click the header's external-link button | Launch `pavucontrol`, close the card. |
| Escape, or click outside | Close the card. |

Opening the card closes any other quick panel, the same as the calendar and
cava. The advanced mixer is still one click away through the header button.

## Settings survive a reboot

The card writes no settings file. WirePlumber restores every choice on its own
from `~/.local/state/wireplumber/`: the default output and input from
`default-nodes`, device volumes and mutes from `default-routes`, and per-app
volumes and mutes from `stream-properties`, through the default-on
`node.stream.restore-props` setting. A per-app volume comes back the next time
that app opens a stream, so after a reboot Spotify returns at its saved level
once it plays again.

## From a keybind or script

The `audio` target toggles and closes the card:

```sh
quickshell ipc call audio toggle
quickshell ipc call audio close
```

`toggle` prints `ok` or `error: audio module is hidden`; `close` prints nothing.
[IPC targets](ipc.md) lists the return values and the other targets.
