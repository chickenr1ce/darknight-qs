# Performance tab

The dashboard's Performance tab answers "what happened, and when?". Every metric
is a lane on one shared time axis, so a spike in one lane lines up with whatever
else happened at that moment. Open it from the dashboard's tab row or with
`quickshell ipc call dashboard performance`.

## The lanes

- **CPU**: the filled area is the average across all threads. The thin bright
  line is whichever thread was busiest at that moment. A wide gap between them
  means one thread is maxed out while the rest are idle.
- **GPU**: GPU use.
- **RAM**: memory in use, with the used and total amounts in the readout.
- **DISK**: reads above the centre line, writes below it, across all whole disks.
- **NET**: downloads above the centre line, uploads below it.

The readouts sit to the left of each lane. CPU and GPU temperatures say `Warm`
from 75°C and `Hot` from 85°C. DISK and NET scale to their busiest moment in the
visible range, and `peak` names that value, so compare their shapes rather than
their heights against each other.

## Time range and hover

- `1m` and `5m` choose the visible range. The tab reopens on `5m` after a shell
  restart.
- Hover a lane to scrub. The line follows the pointer, and every readout and the
  heading show that moment. Move away to return to the current values.

## What it records

The tab samples every 2 seconds and keeps the last 5 minutes in memory. It keeps
recording while the dashboard is closed, so you can open it after a stutter and
look back. The history starts empty when the shell starts or reloads, and fills
in from the right.
