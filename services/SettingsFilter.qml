pragma Singleton

import QtQuick

QtObject {
    id: root

    function filtering(filter: string): bool {
        return filter !== "";
    }

    function matches(filter: string, label: string): bool {
        if (!root.filtering(filter))
            return true;
        return label.toLowerCase().includes(filter.toLowerCase());
    }
}
