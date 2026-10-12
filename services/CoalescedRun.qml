import QtQuick
import "CoalescedRunLogic.js" as CoalescedRunLogic

// The shared "if busy, remember one request; on exit, drain it" run wrapper.
//
// Contract:
// - starter(arg) launches the run. It returns false to declare that it did
//   NOT launch (a precondition died by start time); the wrapper then finishes
//   the run with ok=true. Returning undefined or true declares a launch, so a
//   starter that just sets running = true is a launcher.
// - The module state is the only truth for running. A deferred drain counts
//   as running, so a request landing in that tick queues instead of
//   double-starting.
// - When `process` is bound, the wrapper also watches the launch itself: a
//   process that never runs (a missing binary, an exec with an empty command)
//   or drops back to not-running without an exited is finished(false) here,
//   so a failed launch cannot wedge the run forever. A real exit still closes
//   the run through the service's Process.onExited, exactly once.
QtObject {
    id: root

    property bool gated: false
    property int maxRetries: 0
    property var starter: null
    property var process: null
    readonly property bool running: root.state.running
    property var state: CoalescedRunLogic.initial()
    property int launchSeq: 0
    property bool exitSeen: false

    // The wrapper's own exit witness. onExited marks the launch as closed by
    // the service; a running-false with no witness defers a check that closes
    // a launch which never started.
    property Connections processConnection: Connections {
        id: idProcessConnection

        target: root.process

        function onExited(exitCode, exitStatus) {
            root.exitSeen = true;
        }

        function onRunningChanged() {
            if (root.process !== null && !root.process.running) {
                const seq = root.launchSeq;
                Qt.callLater(() => root.checkLaunch(seq));
            }
        }
    }

    signal retry()

    function request(arg) {
        const r = CoalescedRunLogic.request(root.state, arg, { gated: root.gated });
        root.state = r.state;
        if (r.start)
            root.launch(r.arg);
    }

    // Call from the run's Process's onExited only, once per run. A queued
    // request (or retry) drains one tick later, like the callLater drains it
    // replaced.
    function finished(ok: bool) {
        const r = CoalescedRunLogic.exited(root.state, ok, { maxRetries: root.maxRetries });
        root.state = r.state;
        if (r.start)
            Qt.callLater(() => root.launch(r.arg));
        if (r.retry)
            root.retry();
    }

    function release() {
        const r = CoalescedRunLogic.release(root.state);
        root.state = r.state;
        if (r.start)
            root.launch(r.arg);
    }

    function ungate() {
        root.gated = false;
        root.release();
    }

    function resetAttempts() {
        root.state = CoalescedRunLogic.resetAttempts(root.state);
    }

    // Every starter invocation goes through here, so a throwing starter (or a
    // starter declaring no launch) closes the run instead of leaving it
    // phantom-running.
    function launch(arg) {
        root.launchSeq += 1;
        root.exitSeen = false;
        let launched = true;
        try {
            launched = root.starter ? root.starter(arg) : true;
        } catch (e) {
            console.warn("CoalescedRun: starter threw: " + e);
            root.finished(false);
            return;
        }
        if (launched === false) {
            root.finished(true);
            return;
        }
        if (root.process !== null) {
            const seq = root.launchSeq;
            Qt.callLater(() => root.checkLaunch(seq));
        }
    }

    function checkLaunch(seq: int) {
        if (seq !== root.launchSeq || root.exitSeen || !root.running)
            return;
        if (root.process !== null && root.process.running)
            return;
        console.warn("CoalescedRun: launch never ran and never exited; finishing it");
        root.finished(false);
    }
}
