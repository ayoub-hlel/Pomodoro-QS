pragma Singleton
import QtQuick

/**
 * Format — Shared time formatting utilities.
 *
 * AXIOM_TIME: All inputs in integer seconds.
 */
QtObject {
    /**
     * Format seconds to human-readable duration: "1h 30m" or "45m"
     */
    function duration(s) {
        if (!s || s <= 0) return ""
        s = Math.floor(s)
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60)
        return (h > 0 ? h + "h " : "") + m + "m"
    }

    /**
     * Format seconds to timer display: "25:00" or "1:00:00"
     * Shows hours only when >0, always shows MM:SS.
     */
    function timer(s) {
        if (s === undefined || s === null) s = 0
        s = Math.max(0, Math.floor(s))
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60
        if (h > 0) {
            return h + ":" +
                (m < 10 ? "0" : "") + m + ":" +
                (sec < 10 ? "0" : "") + sec
        }
        return (m < 10 ? "0" : "") + m + ":" + (sec < 10 ? "0" : "") + sec
    }

    /**
     * Format seconds to compact timer: "1:00:00" always HH:MM:SS
     */
    function fullTimer(s) {
        if (s === undefined || s === null) s = 0
        s = Math.max(0, Math.floor(s))
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60
        return (h < 10 ? "0" : "") + h + ":" +
            (m < 10 ? "0" : "") + m + ":" +
            (sec < 10 ? "0" : "") + sec
    }
}
