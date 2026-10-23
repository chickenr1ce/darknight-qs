pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.config
import "LockLogic.js" as LockLogic
import "PowerLogic.js" as PowerLogic

Singleton {
    id: root

    readonly property string userName: Quickshell.env("USER") || ""
    readonly property string userInitial: LockLogic.initial(root.userName)
    readonly property var powerActions: {
        const chrome = {
            suspend: Icons.powerSleep,
            reboot: Icons.restart,
            shutdown: Icons.power
        };
        const entries = LockLogic.powerActions(PowerLogic.actions());
        const out = [];
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i];
            out.push({
                id: entry.id,
                label: entry.label,
                dangerous: entry.dangerous,
                argv: entry.argv,
                hint: entry.hint,
                glyph: chrome[entry.id]
            });
        }
        return out;
    }

    property bool locked: false
    property double lockedAt: 0
    property string authState: "idle"
    property int attempts: 0
    property string pamMessage: ""
    property bool pamMessageIsError: false
    property string pendingPassword: ""
    property string powerArmed: ""
    property bool powerOpen: false
    property bool previewOpen: false
    property string previewPhase: "idle"

    function lock(): void {
        if (root.locked)
            return;
        root.lockedAt = Date.now();
        root.authState = "idle";
        root.attempts = 0;
        root.pamMessage = "";
        root.pamMessageIsError = false;
        root.pendingPassword = "";
        root.powerOpen = false;
        root.powerArmed = "";
        root.previewOpen = false;
        root.previewPhase = "idle";
        root.locked = true;
    }

    function unlocked(): void {
        root.authState = "idle";
        root.attempts = 0;
        root.pamMessage = "";
        root.pamMessageIsError = false;
        root.pendingPassword = "";
        root.powerOpen = false;
        root.powerArmed = "";
        root.locked = false;
    }

    function submit(password: string): void {
        if (!root.locked || root.authState === "checking" || password === "")
            return;
        root.pendingPassword = password;
        root.authState = "checking";
        root.pamMessage = "";
        root.pamMessageIsError = false;
        if (idPam.start())
            return;
        root.pendingPassword = "";
        root.authState = "failed";
        root.attempts += 1;
        idFailureReset.restart();
    }

    function clearFailure(): void {
        if (!root.locked || root.authState !== "failed")
            return;
        idFailureReset.stop();
        root.authState = "idle";
        root.pamMessage = "";
        root.pamMessageIsError = false;
    }

    function applyCompleted(result: int): void {
        if (!root.locked) {
            root.pendingPassword = "";
            return;
        }
        root.pendingPassword = "";
        if (result === PamResult.Success) {
            root.unlocked();
            return;
        }
        root.authState = "failed";
        root.attempts += 1;
        idFailureReset.restart();
    }

    function togglePowerCard(): void {
        if (root.powerOpen) {
            root.closePower();
            return;
        }
        root.powerOpen = true;
        root.powerArmed = "";
    }

    function closePower(): void {
        root.powerOpen = false;
        root.powerArmed = "";
    }

    function armPower(id: string): void {
        root.powerArmed = PowerLogic.press({ armed: root.powerArmed }, id).state.armed;
    }

    function cancelPower(): void {
        root.powerArmed = PowerLogic.cancel({ armed: root.powerArmed }).armed;
    }

    function confirmPower(): void {
        const result = PowerLogic.confirm({ armed: root.powerArmed });
        root.powerArmed = result.state.armed;
        root.powerOpen = false;
        if (result.run === null || !root.locked)
            return;
        idRunProcess.command = result.run;
        idRunProcess.running = true;
    }

    function powerKey(key: string): string {
        const route = LockLogic.powerRoute(root.powerActions, root.powerArmed, key);
        if (route.kind === "arm")
            root.powerArmed = route.id;
        else if (route.kind === "confirm")
            root.confirmPower();
        else if (route.kind === "disarm")
            root.cancelPower();
        else if (route.kind === "close")
            root.closePower();
        return route.kind;
    }

    function revealShown(input): bool {
        return LockLogic.revealShown(input);
    }

    function messageText(authState, pamMessage, pamIsError, attempts): string {
        return LockLogic.messageText(authState, pamMessage, pamIsError, attempts);
    }

    function messageIsError(authState, pamMessage, pamIsError): bool {
        return LockLogic.messageIsError(authState, pamMessage, pamIsError);
    }

    function capsLockAfterKey(current, isCapsKey, isLetter, upper, shiftHeld): bool {
        return LockLogic.capsLockAfterKey(current, isCapsKey, isLetter, upper, shiftHeld);
    }

    function showPreview(): void {
        if (Quickshell.env("QUICKSHELL_DEV_PROBE") !== "1")
            return;
        root.previewOpen = !root.previewOpen;
        root.previewPhase = "idle";
        root.powerArmed = "";
        if (root.previewOpen)
            root.lockedAt = Date.now();
    }

    function showPreviewPhase(phase: string): void {
        if (Quickshell.env("QUICKSHELL_DEV_PROBE") !== "1")
            return;
        if (["idle", "typing", "checking", "failed", "power"].indexOf(phase) === -1)
            return;
        root.previewOpen = true;
        root.previewPhase = phase;
        root.lockedAt = Date.now();
        root.powerArmed = "";
        root.attempts = phase === "failed" ? 3 : 0;
    }

    PamContext {
        id: idPam

        config: "login"

        onPamMessage: {
            if (idPam.responseRequired) {
                const password = root.pendingPassword;
                root.pendingPassword = "";
                idPam.respond(password);
                return;
            }
            root.pamMessage = idPam.message;
            root.pamMessageIsError = idPam.messageIsError;
        }

        onCompleted: result => root.applyCompleted(result)
    }

    Timer {
        id: idFailureReset

        interval: Globals.lockFailureResetMs
        onTriggered: root.clearFailure()
    }

    Process {
        id: idRunProcess
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function status(): string {
            return JSON.stringify({
                locked: root.locked,
                authState: root.authState,
                attempts: root.attempts,
                powerOpen: root.powerOpen,
                previewOpen: root.previewOpen,
                previewPhase: root.previewPhase
            });
        }

        function preview(): void {
            root.showPreview();
        }

        function previewState(state: string): void {
            root.showPreviewPhase(state);
        }
    }
}
