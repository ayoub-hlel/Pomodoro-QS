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
 * Persistence hooks:
 *   - saveRequested(taskId, elapsed) emitted on pause/stop/switch
 *     so the consumer can write accumulated time to TaskDB
 *   - Auto-resets to idle 5s after reaching "done"
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
    property string activeTaskName: ""  // task title from the consumer

    // ── Configuration ────────────────────────────────────────────
    property int workDuration: 1500     // 25 min default
    property int breakDuration: 300     // 5 min default

    // ── Signals ──────────────────────────────────────────────────
    signal finished()                   // emitted when break → done (cycle complete)
    signal timerStateChanged(string newState)
    /** Emitted when time should be persisted: pause/stop/before-task-switch */
    signal saveRequested(int taskId, int elapsedSeconds)

    // ── Internal ─────────────────────────────────────────────────
    property double _runStart: 0
    property int _initTime: 0
    property int _accumulated: 0
    property string _prevState: "idle"

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
                // Save work session time before moving to break
                root.saveRequested(root.activeTaskId, root.elapsed);
                _prevState = "break";
                state = "break";
                timerStateChanged("break");
                _beginCountdown(breakDuration);
            } else if (state === "break") {
                _prevState = "done";
                state = "done";
                timerStateChanged("done");
                root.finished();
                _autoResetToIdle();
            }
        }
    }

    /** Auto-return to idle 5 seconds after reaching "done" */
    Timer {
        id: _resetTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (state === "done") {
                _resetInternals();
                activeTaskId = 0;
                activeTaskName = "";
                state = "idle";
                timerStateChanged("idle");
            }
        }
    }

    function _autoResetToIdle() {
        _resetTimer.start();
    }

    // ── Public API ───────────────────────────────────────────────

    /**
     * Start a focus session for a task.
     * If another task is active, emits saveRequested so caller can persist
     * the previous task's elapsed before switching.
     */
    function start(taskId, maybeName, maybeWork, maybeBreak) {
        // If switching tasks mid-session, save current progress first
        if (state !== "idle" && root.activeTaskId > 0 && root.activeTaskId !== taskId) {
            root.saveRequested(root.activeTaskId, root.elapsed);
        }

        // Detect calling convention:
        //   start(id, name, workDur, breakDur)  ← new API
        //   start(id, workDur, breakDur)         ← old API (name is actually workDur)
        var name = "", workDur, breakDur;
        if (typeof maybeName === "string" || maybeName === undefined) {
            name = maybeName || "";
            workDur = maybeWork;
            breakDur = maybeBreak;
        } else {
            // Old convention: start(id, workDur, breakDur)
            workDur = maybeName;
            breakDur = maybeWork;
        }

        if (taskId !== undefined) activeTaskId = Math.max(0, Math.floor(taskId));
        activeTaskName = name;
        if (workDur !== undefined) workDuration = Math.max(1, Math.floor(workDur));
        if (breakDur !== undefined) breakDuration = Math.max(1, Math.floor(breakDur));

        _resetTimer.stop();
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
        root.saveRequested(root.activeTaskId, root.elapsed);
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

        // Persist before reseting
        if (root.activeTaskId > 0 && root.elapsed > 0) {
            root.saveRequested(root.activeTaskId, root.elapsed);
        }

        _ticker.stop();
        _resetTimer.stop();
        _resetInternals();
        activeTaskId = 0;
        activeTaskName = "";
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
