import QtQuick
import QtTest

// The wrapper's event behaviour, offscreen with a mock starter and a mock
// Process-like object: the module state owns liveness (a drain deferred
// through Qt.callLater still counts as running), requests landing in the
// drain tick queue, a starter that cannot launch closes its own run, and a
// bound process that never runs (or never exits) cannot wedge the run.
// qmltestrunner runs this file from a staged gate copy: services/ has a
// qmldir whose singleton modules the plain QML engine cannot load, so
// scripts/test-coalesced-run.sh mirrors this file beside
// services/CoalescedRun.qml in a qmldir-free directory, where the type
// resolves from the same directory. A real Quickshell Process is unavailable
// here (its Quickshell.Io plugin is linked into the shell, not loadable by
// qmltestrunner), so the process cases use a QtObject with `running` and
// `exited`, the same surface the wrapper watches. The type is only ever
// resolved from the staging dir, so the import check is off here.
// qmllint disable import
// qmllint disable unqualified
// This is wired into scripts/test-coalesced-run.sh.
TestCase {
    id: root

    property string startedArgs: ""
    property int retries: 0
    property bool finishOnStart: false
    property QtObject mockProcess: null
    property bool useMockProcess: false
    property bool starterReturnsFalse: false
    property bool starterThrows: false
    property int startCount: 0
    property CoalescedRun serviceRun: null

    name: "CoalescedRun"

    Component {
        id: idMockProcessFactory

        QtObject {
            id: idMockProcess

            property bool running: false

            signal exited(int exitCode, int exitStatus)
        }
    }

    // The service's half of the contract: its Process.onExited closes the run.
    Connections {
        id: idServiceConnection

        target: root.mockProcess

        function onExited(exitCode, exitStatus) {
            if (root.serviceRun !== null)
                root.serviceRun.finished(exitCode === 0);
        }
    }

    Component {
        id: idRunFactory

        CoalescedRun {
            id: idRun

            process: root.mockProcess
            starter: arg => {
                root.startedArgs += arg + ",";
                root.startCount = root.startCount + 1;
                if (root.starterThrows && root.startCount === 1)
                    throw new Error("starter failed");
                if (root.finishOnStart) {
                    idRun.finished(true);
                    return true;
                }
                if (root.starterReturnsFalse)
                    return false;
                if (root.useMockProcess && root.mockProcess !== null)
                    root.mockProcess.running = true;
                return true;
            }
            onRetry: root.retries = root.retries + 1
        }
    }

    function init(): void {
        root.startedArgs = "";
        root.retries = 0;
        root.finishOnStart = false;
        root.mockProcess = null;
        root.useMockProcess = false;
        root.starterReturnsFalse = false;
        root.starterThrows = false;
        root.startCount = 0;
        root.serviceRun = null;
    }

    function makeRun(): var {
        return idRunFactory.createObject(root);
    }

    function test_requestIdleStartsOnceWithArg(): void {
        const run = root.makeRun();
        run.request("a");
        compare(root.startedArgs, "a,", "the starter fired once with the arg");
        verify(run.running, "the run is running after an idle request");
        run.destroy();
    }

    function test_requestWhileRunningIsHeldUntilDrain(): void {
        const run = root.makeRun();
        run.request("a");
        run.request("b");
        compare(root.startedArgs, "a,", "a busy request did not start");
        run.finished(true);
        compare(root.startedArgs, "a,", "the drained start is deferred");
        wait(20);
        compare(root.startedArgs, "a,b,", "the drained start fired on the next tick");
        run.destroy();
    }

    function test_requestInDrainTickQueuesInsteadOfStarting(): void {
        const run = root.makeRun();
        run.request("a");
        run.request("b");
        run.finished(true);
        compare(root.startedArgs, "a,", "b drains deferred");
        run.request("c");
        compare(root.startedArgs, "a,", "c did not double-start inside the tick");
        verify(run.running, "the deferred drain still counts as running");
        compare(run.state.pendingArg, "c", "c is queued as the latest arg");
        wait(20);
        compare(root.startedArgs, "a,b,", "b ran with its own arg");
        run.finished(true);
        wait(20);
        compare(root.startedArgs, "a,b,c,", "c drained after b finishes");
        run.finished(true);
        verify(!run.running, "the run idled after c");
        run.destroy();
    }

    function test_failedFinishSignalsRetryAndHolds(): void {
        const run = root.makeRun();
        run.maxRetries = 2;
        run.request("p");
        run.finished(false);
        compare(root.retries, 1, "the first failure signals retry");
        compare(root.startedArgs, "p,", "the retry waits for release()");
        run.release();
        compare(root.startedArgs, "p,p,", "release replays the failed arg");
        run.finished(false);
        compare(root.retries, 2, "the second failure signals retry");
        run.release();
        run.finished(false);
        compare(root.retries, 2, "the budget of 2 caps the retry signal");
        run.destroy();
    }

    function test_syncFinishedStarterLeavesTheRunIdle(): void {
        const run = root.makeRun();
        root.finishOnStart = true;
        run.request("x");
        compare(root.startedArgs, "x,", "the starter ran once");
        verify(!run.running, "a starter that finishes synchronously idles the run");
        run.request("y");
        compare(root.startedArgs, "x,y,", "a closed no-op run is immediately reusable");
        run.destroy();
    }

    // (a) A launch whose process drops running without ever exiting must
    // finish once (not wedge), and the next request must start.
    function test_missingLaunchFinishesOnceAndAllowsNextRequest(): void {
        const mock = idMockProcessFactory.createObject(root);
        root.mockProcess = mock;
        root.useMockProcess = true;
        const run = root.makeRun();
        run.maxRetries = 2;
        run.request("a");
        verify(run.running, "the run is running after the launch");
        mock.running = false;
        wait(20);
        compare(root.retries, 1, "the failed launch finished exactly once");
        verify(!run.running, "the run idled instead of wedging");
        run.request("b");
        compare(root.startedArgs, "a,b,", "the next request starts after the failed launch");
        verify(run.running, "the next request owns the run");
        run.destroy();
        mock.destroy();
    }

    function test_exitRaceFinishesOnceInEitherOrder(): void {
        root.assertExitRace(false);
        root.assertExitRace(true);
    }

    function assertExitRace(runningFirst: bool): void {
        const mock = idMockProcessFactory.createObject(root);
        root.mockProcess = mock;
        root.useMockProcess = true;
        const run = root.makeRun();
        run.maxRetries = 3;
        root.serviceRun = run;
        run.request("a");
        if (runningFirst) {
            mock.running = false;
            mock.exited(0, 0);
        } else {
            mock.exited(0, 0);
            mock.running = false;
        }
        wait(20);
        compare(root.retries, 0, "the exited run finished once with no retry (" + (runningFirst ? "false-first" : "exit-first") + ")");
        verify(!run.running, "the run idled after the exit");
        run.destroy();
        mock.destroy();
        root.serviceRun = null;
        root.mockProcess = null;
        root.startedArgs = "";
        root.retries = 0;
    }

    // (c) A starter that throws must not leave the run phantom-running.
    function test_throwingStarterIdlesAndAllowsNextRequest(): void {
        const run = root.makeRun();
        root.starterThrows = true;
        run.request("a");
        compare(root.startedArgs, "a,", "the throwing starter ran");
        verify(!run.running, "the run idled after the starter threw");
        run.request("b");
        compare(root.startedArgs, "a,b,", "the next request starts");
        verify(run.running, "the next request owns the run");
        run.destroy();
    }

    // (d) A starter returning false declares no launch: finish ok, no retry.
    function test_starterReturnsFalseIdlesWithoutRetry(): void {
        const run = root.makeRun();
        run.maxRetries = 2;
        root.starterReturnsFalse = true;
        run.request("a");
        compare(root.startedArgs, "a,", "the no-launch starter ran");
        verify(!run.running, "a declared no-launch idled the run");
        compare(root.retries, 0, "a declared no-launch finishes ok, not failed");
        root.starterReturnsFalse = false;
        run.request("b");
        compare(root.startedArgs, "a,b,", "the run is immediately reusable");
        verify(run.running, "the next request owns the run");
        run.destroy();
    }
}
