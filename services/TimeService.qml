pragma Singleton
import QtQuick

Item {
    id: root

    // --- State ---
    property string mode: "idle" // idle, focus, short_break, long_break, flow
    property int timeLeft: 0
    property int elapsed: 0
    property bool isRunning: false
    property int activeTaskId: 0

    // --- Internal ---
    property double _startTime: 0
    property int _initialTime: 0
    property int _totalElapsed: 0

    signal finished()

    Timer {
        id: ticker
        interval: 1000
        repeat: true
        onTriggered: {
            let now = Date.now();
            let delta = Math.floor((now - _startTime) / 1000);
            
            elapsed = _totalElapsed + delta;
            
            if (mode !== "flow") {
                timeLeft = Math.max(0, _initialTime - delta);
                if (timeLeft === 0) {
                    root.stop();
                    root.finished();
                }
            }
        }
    }

    function start(newMode, duration = 0, taskId = 0) {
        mode = newMode;
        activeTaskId = taskId;
        _initialTime = Math.max(0, duration);
        timeLeft = _initialTime;
        _totalElapsed = 0;
        elapsed = 0;
        _startTime = Date.now();
        isRunning = true;
        ticker.start();
    }

    function pause() {
        if (!isRunning) return;
        
        let delta = Math.floor((Date.now() - _startTime) / 1000);
        _totalElapsed += delta;
        
        // Sync timeLeft one last time before stopping
        timeLeft = Math.max(0, _initialTime - delta);
        _initialTime = timeLeft;
        
        ticker.stop();
        isRunning = false;
    }

    function resume() {
        if (isRunning || mode === "idle") return;
        _startTime = Date.now();
        isRunning = true;
        ticker.start();
    }

    function stop() {
        ticker.stop();
        isRunning = false;
        if (mode !== "flow") timeLeft = 0;
        mode = "idle";
        activeTaskId = 0;
    }
}
