import QtQuick
import QtTest

// The Apps view opens the context menu on Right only while the search cursor
// sits at the end of the query, and otherwise leaves the event for the
// TextInput to move the cursor. That relies on the Keys handler attached to
// the focused TextInput seeing Right and being able to swallow it; this runs
// offscreen and is wired into scripts/test-app-launcher.sh.
TestCase {
    id: root

    property int menuOpens: 0
    property int rightSeen: 0

    name: "AppLauncherMenuKeys"
    when: windowShown

    TextInput {
        id: idKeysSearch

        width: 200
        height: 40
        focus: true
        text: "abc"

        Keys.onPressed: event => {
            if (event.key !== Qt.Key_Right)
                return;
            root.rightSeen = root.rightSeen + 1;
            if (idKeysSearch.cursorPosition === idKeysSearch.length) {
                root.menuOpens = root.menuOpens + 1;
                event.accepted = true;
            }
        }
    }

    function init(): void {
        idKeysSearch.text = "abc";
        idKeysSearch.cursorPosition = idKeysSearch.text.length;
        idKeysSearch.forceActiveFocus();
        root.menuOpens = 0;
        root.rightSeen = 0;
    }

    function test_right_at_end_opens_menu(): void {
        keyClick(Qt.Key_Right);
        compare(root.rightSeen, 1, "the handler sees Right at the end");
        compare(root.menuOpens, 1, "Right at the end opens the menu");
        compare(idKeysSearch.cursorPosition, idKeysSearch.length, "the cursor does not move");
    }

    function test_right_mid_text_moves_cursor(): void {
        idKeysSearch.cursorPosition = 1;
        keyClick(Qt.Key_Right);
        compare(root.rightSeen, 1, "the handler sees Right mid-text");
        compare(root.menuOpens, 0, "Right mid-text does not open the menu");
        compare(idKeysSearch.cursorPosition, 2, "the cursor moves instead");
    }

    function test_right_with_empty_text_opens_menu(): void {
        idKeysSearch.text = "";
        idKeysSearch.cursorPosition = 0;
        keyClick(Qt.Key_Right);
        compare(root.menuOpens, 1, "Right on an empty query opens the menu");
    }
}
