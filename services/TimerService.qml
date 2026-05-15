pragma Singleton
import QtQuick

/**
 * TimerService — Minimal Pomodoro State Machine
 *
 * States: idle → running → paused → break → done
 *
 *   start()    : idle → running (begins work countdown)
 *   pause()    : running/break → paused (freeze time)
 *   resume()   : paused → running/break (continue countdown)
 *   stop()     : any → idle (hard reset)
 *   Auto       : running (timeLeft=0) → break (auto-countdown) → done
 *
 * AXIOM_TIME:  All values in integer seconds. No ms, no floats.
 * AXIOM_COLOR: No colors — pure logic service.
 */
Item {
    id: root

    // ── Public State ──────────────────────────────────────────────
    property string state: "idle"       // idle | running | paused | break | done
    property int timeLeft: 0            // seconds remaining in current segment
    property int elapsed: 0             // seconds elapsed in current segment
    property int activeTaskId: 0        // task being timed (0 = none)

    // ── Configuration ────────────────────────────────────────────
    property int workDuration: 1500     // 25 min default
    property int breakDuration: 300     // 5 min default

    // ── Signals ──────────────────────────────────────────────────
    signal finished()                   // emitted when break → done (cycle complete)
    signal timerStateChanged(string newState)  // emitted on every state transition

    // ── Internal ─────────────────────────────────────────────────
    property double _runStart: 0        // Date.now() when last uninterrupted run began
    property int _initTime: 0           // total countdown for current segment
    property int _accumulated: 0        // elapsed prior to latest pause
    property string _prevState: "idle"  // state before pausing

    Timer {
        id: _ticker
        interval: 1000
        repeat: true
        onTriggered: {
            var delta = Math.floor((Date.now() - _runStart) / 1000);
            elapsed = _accumulated + delta;
            timeLeft = Math.max(0, _initTime - delta);

            if (timeLeft > 0) return;

            // Segment expired — stop ticker, advance state
            _ticker.stop();
            _accumulated = 0;

            if (state === "running") {
                _prevState = "break";
                state = "break";
                timerStateChanged("break");
                _beginCountdown(breakDuration);
            } else if (state === "break") {
                state = "done";
                timerStateChanged("done");
                root.finished();
            }
        }
    }

    // ── Public API ───────────────────────────────────────────────

    function start(taskId, workDur, breakDur) {
        if (taskId !== undefined) activeTaskId = Math.max(0, Math.floor(taskId));
        if (workDur !== undefined) workDuration = Math.max(1, Math.floor(workDur));
        if (breakDur !== undefined) breakDuration = Math.max(1, Math.floor(breakDur));
        _prevState = "running";
        state = "running";
        timerStateChanged("running");
        _beginCountdown(workDuration);
    }

    function pause() {
        if (state !== "running" && state !== "break") return;
        var delta = Math.floor((Date.now() - _runStart) / 1000);
        _accumulated += delta;
        _initTime = Math.max(0, _initTime - delta);
        timeLeft = _initTime;
        elapsed = _accumulated;
        _ticker.stop();
        _prevState = state;
        state = "paused";
        timerStateChanged("paused");
    }

    function resume() {
        if (state !== "paused") return;
        state = _prevState;
        timerStateChanged(state);
        _runStart = Date.now();
        _ticker.start();
    }

    function stop() {
        if (state === "idle") return;
        _ticker.stop();
        _resetInternals();
        activeTaskId = 0;
        state = "idle";
        timerStateChanged("idle");
    }

    // ── Internal ─────────────────────────────────────────────────

    function _beginCountdown(duration) {
        _initTime = duration;
        timeLeft = duration;
        _accumulated = 0;
        elapsed = 0;
        _runStart = Date.now();
        _ticker.start();
    }

    function _resetInternals() {
        _initTime = 0;
        timeLeft = 0;
        elapsed = 0;
        _accumulated = 0;
        _runStart = 0;
        _prevState = "idle";
    }
}
