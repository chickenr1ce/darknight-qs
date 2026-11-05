import QtQuick
import QtTest
import qs.services
import "../windows"

// Drives the real windows/DashboardPerformanceView.qml and the real
// services/PerformanceHistory.qml with a fixture SystemMonitor and synthetic
// pointer events: recording, the readouts, scrubbing a lane, a pointer over a
// part of the plot with no history yet, and the range pills. Wired into
// scripts/test-performance.sh.
TestCase {
    id: root

    readonly property int plotLeft: 12 + 128 + 8
    readonly property int plotY: 120

    name: "PerformanceView"
    when: windowShown

    Window {
        width: 696
        height: 400
        visible: true

        DashboardPerformanceView {
            id: idView

            width: 696
        }
    }

    function record(value: real): void {
        SystemMonitor.cpuUsagePercent = value;
        SystemMonitor.cpuPeakPercent = value + 1;
        SystemMonitor.cpuTempC = 80;
        SystemMonitor.gpuUsagePercent = value;
        SystemMonitor.ramUsagePercent = value;
        SystemMonitor.ramUsedBytes = value * 1073741824;
        SystemMonitor.diskReadBytesPerSec = value * 1000;
        SystemMonitor.diskWriteBytesPerSec = value;
        SystemMonitor.netRxBytesPerSec = value;
        SystemMonitor.netTxBytesPerSec = value;
        SystemMonitor.sampled();
    }

    function plotX(fraction: real): real {
        const width = idView.width - root.plotLeft - 12;
        return root.plotLeft + width * fraction;
    }

    function findPill(item, label: string) {
        if (item.text === label && item.clicked !== undefined && item.highlighted !== undefined)
            return item;
        for (let i = 0; i < item.children.length; i++) {
            const found = root.findPill(item.children[i], label);
            if (found !== null)
                return found;
        }
        return null;
    }

    function initTestCase(): void {
        PerformanceHistory.rings = ({ cpu: [], cpuPeak: [], cpuTemp: [], gpu: [], gpuTemp: [], ram: [], ramUsed: [], diskRead: [], diskWrite: [], netRx: [], netTx: [] });
        for (let i = 0; i < 151; i++)
            root.record(i === 0 ? 100 : 10 + i % 7);
    }

    function test_1_recording_is_bounded_and_reads_newest(): void {
        root.record(42);
        compare(PerformanceHistory.rings.cpu.length, PerformanceHistory.capacity, "the ring stays at capacity");
        compare(idView.reading.cpu, 42);
        compare(idView.reading.cpuPeak, 43);
    }

    function test_2_old_spike_counts_only_inside_the_window(): void {
        root.record(90);
        for (let i = 0; i < 40; i++)
            root.record(5);
        idView.windowSeconds = 300;
        compare(idView.diskPeak, 90000, "five minutes still holds the spike");
        idView.windowSeconds = 60;
        compare(idView.diskPeak, 5000, "the spike is older than the last minute");
        idView.windowSeconds = 300;
    }

    function test_3_hover_scrubs_and_leaving_returns_to_now(): void {
        root.record(55);
        mouseMove(idView, root.plotX(0.5), root.plotY);
        wait(50);
        verify(idView.scrubbing, "the pointer over a lane scrubs");
        compare(idView.scrubAge, 75);
        const rings = PerformanceHistory.rings;
        compare(idView.reading.cpu, rings.cpu[rings.cpu.length - 1 - 75]);
        mouseMove(idView, root.plotX(0.999), root.plotY);
        wait(50);
        compare(idView.scrubAge, 0);
        mouseMove(idView, 4, 4);
        wait(50);
        verify(!idView.scrubbing, "leaving the plot stops the scrub");
        compare(idView.reading.cpu, 55);
    }

    function test_4_scrub_stays_on_its_age_as_samples_arrive(): void {
        mouseMove(idView, root.plotX(0.5), root.plotY);
        wait(50);
        const age = idView.scrubAge;
        root.record(77);
        compare(idView.scrubAge, age);
        const rings = PerformanceHistory.rings;
        compare(idView.reading.cpu, rings.cpu[rings.cpu.length - 1 - idView.scrubAge], "the hovered readout refreshes");
        mouseMove(idView, 4, 4);
        wait(50);
    }

    function test_5_range_pills_change_the_window(): void {
        const minute = root.findPill(idView, "1m");
        const five = root.findPill(idView, "5m");
        verify(minute !== null && five !== null);
        mouseClick(minute);
        compare(idView.windowSeconds, 60);
        compare(idView.windowSamples, 31);
        verify(minute.highlighted && !five.highlighted);
        mouseMove(idView, root.plotX(0), root.plotY);
        wait(50);
        compare(idView.scrubAge, 30, "the left edge is the oldest sample of the window");
        mouseMove(idView, 4, 4);
        wait(50);
        mouseClick(five);
        compare(idView.windowSeconds, 300);
    }

    function test_6_pointer_past_the_history_shows_now(): void {
        PerformanceHistory.rings = ({ cpu: [], cpuPeak: [], cpuTemp: [], gpu: [], gpuTemp: [], ram: [], ramUsed: [], diskRead: [], diskWrite: [], netRx: [], netTx: [] });
        for (let i = 0; i < 5; i++)
            root.record(20 + i);
        mouseMove(idView, root.plotX(0.1), root.plotY);
        wait(50);
        verify(idView.scrubAge >= 5);
        verify(!idView.scrubbing, "no sample that old, so no scrub");
        compare(idView.reading.cpu, 24, "the readout stays on the newest sample");
        mouseMove(idView, 4, 4);
        wait(50);
    }
}
