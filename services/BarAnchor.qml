import QtQuick

QtObject {
    id: root

    property Item anchor: null

    signal toggleRequested()

    function register(trigger: Item) {
        root.anchor = trigger;
    }

    function unregister(trigger: Item) {
        if (root.anchor === trigger)
            root.anchor = null;
    }

    function requestToggle(): bool {
        if (root.anchor === null)
            return false;
        root.toggleRequested();
        return true;
    }
}
