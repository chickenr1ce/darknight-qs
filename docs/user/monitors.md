# Monitors

The bar is built for a two-monitor layout. The primary monitor shows the full
bar; every other screen shows the minimal bar (clock and workspaces).

By default the primary is the first connected screen by position: sorted by x,
then y, then name (`config/Globals.qml`). Pick another under Settings → Monitors,
or choose Auto to return to the positional default. The choice persists across
restarts in the shell's state file (`monitor-settings`), not the repo.

The workspace split is fixed. Each monitor owns a contiguous block of
`MonitorService.workspacesPerMonitor` workspaces, five by default, and the block
starts at `firstWorkspaceFor(monitorName)`. With two monitors the second
monitor's workspaces are 6–10 (`modules/Workspaces.qml`).
