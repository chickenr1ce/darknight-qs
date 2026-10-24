pragma Singleton

import Quickshell
import Quickshell.Hyprland
import "HyprlandDispatchLogic.js" as HyprlandDispatchLogic

// The one place a Hyprland IPC payload reaches the compositor. A caller states
// an intent; HyprlandDispatchLogic.js builds the validated Lua string, and this
// module dispatches it live. The recording adapter lives at the JS seam
// (HyprlandDispatchLogic.deliver), where the node tests drive it.
Singleton {
    id: root

    function send(payload): bool {
        return HyprlandDispatchLogic.deliver(payload, null, text => Hyprland.dispatch(text));
    }

    function selector(address): string {
        return HyprlandDispatchLogic.selector(address);
    }

    function escapeLua(value): string {
        return HyprlandDispatchLogic.escapeLua(value);
    }

    function parseCursorPos(text): var {
        return HyprlandDispatchLogic.parseCursorPos(text);
    }

    function focusWorkspace(id): bool {
        return root.send(HyprlandDispatchLogic.focusWorkspace(id));
    }

    function focusWindow(address): bool {
        return root.send(HyprlandDispatchLogic.focusWindow(address));
    }

    function moveWindowToWorkspace(address, id, follow): bool {
        return root.send(HyprlandDispatchLogic.moveWindowToWorkspace(address, id, follow));
    }

    function toggleFloating(address): bool {
        return root.send(HyprlandDispatchLogic.toggleFloating(address));
    }

    function toggleFullscreen(address, mode): bool {
        return root.send(HyprlandDispatchLogic.toggleFullscreen(address, mode));
    }

    function execOnWorkspace(command, id): bool {
        return root.send(HyprlandDispatchLogic.execOnWorkspace(command, id));
    }

    function moveCursor(x, y): bool {
        return root.send(HyprlandDispatchLogic.moveCursor(x, y));
    }
}
