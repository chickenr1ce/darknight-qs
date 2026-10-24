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

    property var session: LockLogic.initialState()

    property bool locked: false

    readonly property string userName: Quickshell.env("USER") || ""
    readonly property string userInitial: LockLogic.initial(root.userName)
    readonly property var powerActions: {
        const rows = PowerLogic.rows("lock");
        for (let i = 0; i < rows.length; i++)
            rows[i].glyph = Icons[rows[i].glyph];
        return rows;
    }
    readonly property string authState: root.session.authState
    readonly property int attempts: root.session.attempts
    readonly property string pamMessage: root.session.pamMessage
    readonly property bool pamMessageIsError: root.session.pamMessageIsError
    readonly property double lockedAt: root.session.lockedAt
    readonly property bool powerOpen: root.session.powerOpen
    readonly property string powerArmed: root.session.powerArmed
    readonly property string powerQuestion: PowerLogic.question(root.session.powerArmed)
    readonly property bool previewOpen: root.session.previewOpen
    readonly property string previewPhase: root.session.previewPhase

    function apply(result: var): void {
        root.locked = result.state.locked;
        root.session = result.state;
        for (let i = 0; i < result.effects.length; i++)
            root.applyEffect(result.effects[i]);
    }

    function dispatch(event: var): void {
        root.apply(LockLogic.reduce(root.session, event));
    }

    function startAuth(password: string): void {
        idPamAdapter.password = password;
        if (root.session.previewOpen) {
            Qt.callLater(() => root.dispatch({ kind: "pamCompleted", success: false }));
            return;
        }
        if (idPam.start())
            return;
        idPamAdapter.password = "";
        root.dispatch({ kind: "startFailed" });
    }

    function respondAuth(): void {
        const password = idPamAdapter.password;
        idPamAdapter.password = "";
        if (!root.session.previewOpen)
            idPam.respond(password);
    }

    function applyEffect(effect: var): void {
        if (effect.kind === "pamStart") {
            root.startAuth(effect.password);
            return;
        }
        if (effect.kind === "pamRespond") {
            root.respondAuth();
            return;
        }
        if (effect.kind === "pamAbort") {
            idPamAdapter.password = "";
            if (!root.session.previewOpen)
                idPam.abort();
            return;
        }
        if (effect.kind === "pamReset") {
            idPamAdapter.password = "";
            return;
        }
        if (effect.kind === "restartFailureTimer") {
            idFailureReset.restart();
            return;
        }
        if (effect.kind === "stopFailureTimer") {
            idFailureReset.stop();
            return;
        }
        if (effect.kind === "run") {
            idRunProcess.command = effect.argv;
            idRunProcess.running = true;
        }
    }

    function lock(): void {
        root.dispatch({ kind: "lock", now: Date.now() });
    }

    function canSubmit(password: string): bool {
        return LockLogic.canSubmit(root.session, password);
    }

    function submit(password: string): void {
        root.dispatch({ kind: "submit", password: password });
    }

    function clearFailure(): void {
        root.dispatch({ kind: "failureReset" });
    }

    function togglePowerCard(): void {
        root.dispatch({ kind: "togglePower" });
    }

    function closePower(): void {
        root.dispatch({ kind: "closePower" });
    }

    function armPower(id: string): void {
        root.apply(LockLogic.arm(root.session, PowerLogic.press({ armed: root.session.powerArmed }, id).state.armed));
    }

    function cancelPower(): void {
        root.dispatch({ kind: "cancelPower" });
    }

    function confirmPower(): void {
        root.apply(LockLogic.confirm(root.session, PowerLogic.confirm({ armed: root.session.powerArmed })));
    }

    function powerKey(key: string): string {
        const route = PowerLogic.route("lock", root.session.powerArmed, key);
        const resolution = route.kind === "confirm"
            ? PowerLogic.confirm({ armed: root.session.powerArmed })
            : null;
        root.apply(LockLogic.powerKey(root.session, route, resolution));
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
        root.dispatch({ kind: "previewToggle", now: Date.now() });
    }

    function showPreviewPhase(phase: string): void {
        if (Quickshell.env("QUICKSHELL_DEV_PROBE") !== "1")
            return;
        root.dispatch({ kind: "previewPhase", phase: phase, now: Date.now() });
    }

    QtObject {
        id: idPamAdapter

        property string password: ""
    }

    PamContext {
        id: idPam

        config: "login"

        onPamMessage: {
            if (idPam.responseRequired) {
                root.dispatch({ kind: "pamPrompt" });
                return;
            }
            root.dispatch({
                kind: "pamMessage",
                text: idPam.message,
                isError: idPam.messageIsError
            });
        }

        onCompleted: result => root.dispatch({
            kind: "pamCompleted",
            success: result === PamResult.Success
        })
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
