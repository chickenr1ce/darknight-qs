pragma Singleton

import QtQuick
import "SettingsLogic.js" as SettingsLogic

QtObject {
    id: root

    function filtering(filter: string): bool {
        return SettingsLogic.filtering(filter);
    }

    function matches(filter: string, label: string): bool {
        return SettingsLogic.matches(filter, label);
    }

    function sectionMatches(query: string, title: string, options: var): bool {
        return SettingsLogic.sectionMatches(query, title, options);
    }
}
