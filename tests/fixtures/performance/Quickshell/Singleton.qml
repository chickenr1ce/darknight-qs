import QtQuick

// Stands in for Quickshell's Singleton so the real PerformanceHistory.qml loads
// under qmltestrunner, where the Quickshell plugin cannot.
QtObject {
    id: root

    default property list<QtObject> content
}
