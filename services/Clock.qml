pragma Singleton
import QtQuick

/**
 * Clock — Keeps time for the application.
 */
Item {
    id: root

    property int timestamp: Math.floor(Date.now() / 1000)
    property int todayStart: _getTodayStart()

    signal dayChanged()
    signal minuteChanged()

    Timer {
        interval: 10000; running: true; repeat: true
        onTriggered: {
            let oldT = root.todayStart;
            root.timestamp = Math.floor(Date.now() / 1000);
            root.minuteChanged();
            
            let newT = _getTodayStart();
            if (newT !== oldT) {
                root.todayStart = newT;
                root.dayChanged();
            }
        }
    }

    function _getTodayStart() {
        let d = new Date(); d.setHours(0,0,0,0);
        return Math.floor(d.getTime() / 1000);
    }
}
