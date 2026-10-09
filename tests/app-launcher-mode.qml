import QtQuick
import QtTest

TestCase {
    id: root

    property string query: ""
    readonly property bool querying: root.query.trim() !== ""
    property int browseSelected: -1
    property int resultSelected: -1
    property int browseTops: 0
    property int resultTops: 0
    property int browseStops: 0
    property int resultStops: 0

    name: "AppLauncherMode"

    onQueryChanged: {
        const querying = root.query.trim() !== "";
        if (querying) {
            root.resultSelected = 0;
            root.resultTops++;
        } else {
            root.browseSelected = 0;
            root.browseTops++;
        }
    }
    onQueryingChanged: {
        root.browseStops++;
        root.resultStops++;
    }

    function init(): void {
        root.query = "";
        root.browseSelected = 4;
        root.resultSelected = 4;
        root.browseTops = 0;
        root.resultTops = 0;
        root.browseStops = 0;
        root.resultStops = 0;
    }

    function test_enter_query_selects_result(): void {
        root.query = "f";
        compare(root.resultSelected, 0);
        compare(root.resultTops, 1);
        compare(root.browseTops, 0);
    }

    function test_clear_selects_browse(): void {
        root.query = "f";
        root.browseTops = 0;
        root.resultTops = 0;
        root.query = "";
        compare(root.browseSelected, 0);
        compare(root.browseTops, 1);
        compare(root.resultTops, 0);
    }

    function test_keystroke_reselects_first_result(): void {
        root.query = "f";
        root.resultSelected = 5;
        root.query = "fi";
        compare(root.resultSelected, 0);
        compare(root.resultTops, 2);
    }

    function test_mode_flip_stops_both_wheels(): void {
        root.query = "f";
        const stopsAfterEnter = root.resultStops;
        root.query = "";
        compare(root.resultStops, stopsAfterEnter + 1);
        compare(root.browseStops, stopsAfterEnter + 1);
    }

    function test_querying_binding_is_fresh_after_write(): void {
        root.query = "f";
        verify(root.querying, "querying is true after entering a query");
        root.query = "";
        verify(!root.querying, "querying is false after clearing");
    }
}
