import QtQuick
import QtQuick.Layouts
import qs.services

/**
 * TimerDisplay — Visual Pomodoro timer widget.
 *
 * Binds directly to TimerService singleton. Adapts to all 5 states:
 *
 *   idle    → "READY" badge, start button, shows default workDuration
 *   running → "FOCUS" badge, countdown, pause+stop buttons
 *   paused  → dimmed frozen display, resume+stop buttons
 *   break   → "BREAK" badge, tertiary color, countdown, pause+stop
 *   done    → "DONE!" badge, celebrate color, start new cycle button
 *
 * AXIOM_COLOR: All colors from Colours.palette / Colours.tPalette.
 * AXIOM_ANIM:  Every visual property change has Behavior animation.
 * AXIOM_DB:    No database access — pure UI binding to TimerService.
 */
Item {
    id: root

    // ── Public Properties ──────────────────────────────────────────
    /** Compact mode — single horizontal row, smaller fonts */
    property bool compact: false

    // ── Derived State ──────────────────────────────────────────────
    readonly property string _label: {
        switch (TimerService.state) {
            case "idle":    return "READY"
            case "running": return "FOCUS"
            case "paused":  return "PAUSED"
            case "break":   return "BREAK"
            case "done":    return "DONE!"
            default:        return ""
        }
    }

    readonly property color _stateColor: {
        switch (TimerService.state) {
            case "idle":    return Colours.palette.m3onSurfaceVariant
            case "running": return Colours.palette.m3primary
            case "paused":  return Colours.palette.m3onSurfaceVariant
            case "break":   return Colours.palette.m3tertiary
            case "done":    return Colours.palette.m3success
            default:        return Colours.palette.m3onSurface
        }
    }

    readonly property color _bgTint: {
        switch (TimerService.state) {
            case "running": return Qt.alpha(Colours.palette.m3primary, 0.07)
            case "break":   return Qt.alpha(Colours.palette.m3tertiary, 0.07)
            case "done":    return Qt.alpha(Colours.palette.m3success, 0.07)
            default:        return "transparent"
        }
    }

    /** Fraction of current segment remaining (0..1) */
    readonly property real _progress: {
        if (TimerService.state === "idle" || TimerService.state === "done") return 1.0
        var total = TimerService.state === "break"
            ? TimerService.breakDuration
            : TimerService.workDuration
        if (total <= 0) return 0
        return Math.min(1.0, Math.max(0, TimerService.timeLeft / total))
    }

    /** Time to show — default workDuration when idle, otherwise timer timeLeft */
    readonly property int _displayTime: {
        if (TimerService.state === "idle") return TimerService.workDuration
        return TimerService.timeLeft
    }

    readonly property bool _live:   TimerService.state === "running" || TimerService.state === "break"
    readonly property bool _active: TimerService.state !== "idle"

    implicitHeight: compact ? 80 : col.implicitHeight + 32

    // ── Format seconds as MM:SS ───────────────────────────────────
    function _fmt(s) {
        if (s === undefined || s === null) s = 0
        var m = Math.floor(Math.max(0, s) / 60)
        var sec = Math.max(0, Math.floor(s)) % 60
        return (m < 10 ? "0" : "") + m + ":" + (sec < 10 ? "0" : "") + sec
    }

    // ══════════════════════════════════════════════════════════════

    // ── Background Card ───────────────────────────────────────────
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 18
        color: Colours.tPalette.m3surfaceContainerLow
        Behavior on color { ColorAnimation { duration: 300 } }

        // State-tint overlay
        Rectangle {
            anchors.fill: parent
            radius: 18
            color: root._bgTint
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        // Subtle top edge highlight
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1
            color: Qt.alpha(root._stateColor, 0.15)
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    // ── Full Layout ───────────────────────────────────────────────
    ColumnLayout {
        id: col
        anchors {
            top: parent.top; left: parent.left; right: parent.right
            topMargin: 20; leftMargin: 24; rightMargin: 24
        }
        spacing: 4
        visible: !root.compact

        // ── State Badge ───────────────────────────────────────────
        Text {
            id: badge
            Layout.alignment: Qt.AlignHCenter
            text: root._label
            font.pixelSize: 11
            font.letterSpacing: 2.5
            font.family: "Rubik"
            color: root._stateColor
            opacity: TimerService.state === "idle" ? 0.45 : 1.0
            Behavior on color { ColorAnimation { duration: 300 } }
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        // ── Time Display (MM:SS) ─────────────────────────────────
        Text {
            id: timeDisplay
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            text: root._fmt(root._displayTime)
            font.pixelSize: 64
            font.family: "CaskaydiaCove NF"
            font.weight: Font.Bold
            color: TimerService.state === "paused"
                ? Colours.palette.m3onSurfaceVariant
                : Colours.palette.m3onSurface
            opacity: TimerService.state === "paused" ? 0.55 : 1.0
            Behavior on color { ColorAnimation { duration: 300 } }
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        // ── Segment Duration Context ──────────────────────────────
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: {
                if (TimerService.state === "idle")
                    return root._fmt(TimerService.workDuration) + " focus"
                if (TimerService.state === "break" || TimerService.state === "running")
                    return "of " + root._fmt(
                        TimerService.state === "break"
                            ? TimerService.breakDuration
                            : TimerService.workDuration
                    )
                return ""
            }
            font.pixelSize: 12
            font.family: "CaskaydiaCove NF"
            color: Colours.palette.m3onSurfaceVariant
            opacity: 0.7
            visible: TimerService.state !== "done"
        }

        // ── Elapsed ───────────────────────────────────────────────
        Text {
            id: elapsedLabel
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            text: "elapsed " + root._fmt(TimerService.elapsed)
            font.pixelSize: 12
            font.family: "CaskaydiaCove NF"
            color: Colours.palette.m3onSurfaceVariant
            opacity: root._active ? 0.75 : 0.0
            visible: root._active
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        // ── Active Task ───────────────────────────────────────────
        Text {
            id: taskLabel
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            text: TimerService.activeTaskId > 0
                ? "Task #" + TimerService.activeTaskId
                : ""
            font.pixelSize: 12
            font.family: "Rubik"
            color: Colours.palette.m3primary
            visible: text.length > 0
        }

        // ── Progress Bar ──────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            Layout.topMargin: 12
            Layout.bottomMargin: 4
            visible: root._active

            Rectangle {
                anchors.fill: parent
                radius: 2
                color: Colours.tPalette.m3surfaceContainerHigh
            }
            Rectangle {
                id: progressFill
                width: root._progress * parent.width
                height: parent.height
                radius: 2
                color: root._stateColor
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }

        // ── Control Buttons ───────────────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            spacing: 14

            TimerControlButton {
                icon: "\ue037"; label: "Start"
                visible: TimerService.state === "idle" || TimerService.state === "done"
                onClicked: TimerService.start()
            }

            TimerControlButton {
                icon: "\ue037"; label: "Resume"
                visible: TimerService.state === "paused"
                onClicked: TimerService.resume()
            }

            TimerControlButton {
                icon: "\ue034"; label: "Pause"
                btnColor: Colours.tPalette.m3surfaceContainerHigh
                btnTextColor: Colours.palette.m3onSurface
                visible: root._live
                onClicked: TimerService.pause()
            }

            TimerControlButton {
                icon: "\ue5cd"; label: "Stop"
                btnColor: Qt.alpha(Colours.palette.m3error, 0.12)
                btnTextColor: Colours.palette.m3error
                visible: root._active
                onClicked: TimerService.stop()
            }
        }

        // ── Bottom spacer ─────────────────────────────────────────
        Item { Layout.preferredHeight: 8 }
    }

    // ── Compact Layout (single row) ───────────────────────────────
    RowLayout {
        id: compactLayout
        anchors { fill: parent; margins: 12 }
        spacing: 12
        visible: root.compact

        // State dot
        Rectangle {
            Layout.preferredWidth: 8
            Layout.preferredHeight: 8
            radius: 4
            color: root._stateColor
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        // Time
        Text {
            text: root._fmt(root._displayTime)
            font.pixelSize: 24
            font.family: "CaskaydiaCove NF"
            font.weight: Font.Bold
            color: TimerService.state === "paused"
                ? Colours.palette.m3onSurfaceVariant
                : Colours.palette.m3onSurface
            opacity: TimerService.state === "paused" ? 0.6 : 1.0
            Behavior on color { ColorAnimation { duration: 300 } }
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        // Badge
        Text {
            text: root._label
            font.pixelSize: 10
            font.letterSpacing: 1.5
            font.family: "Rubik"
            color: root._stateColor
            opacity: TimerService.state === "idle" ? 0.5 : 1.0
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        Item { Layout.fillWidth: true }

        // Buttons (smaller in compact)
        TimerControlButton { icon: "\ue037"; label: "Start";   btnColor: Colours.palette.m3primary; btnTextColor: Colours.palette.m3onPrimary; implicitWidth: 48; implicitHeight: 40; visible: TimerService.state === "idle" || TimerService.state === "done"; onClicked: TimerService.start() }
        TimerControlButton { icon: "\ue037"; label: "Resume";  btnColor: Colours.palette.m3primary; btnTextColor: Colours.palette.m3onPrimary; implicitWidth: 48; implicitHeight: 40; visible: TimerService.state === "paused"; onClicked: TimerService.resume() }
        TimerControlButton { icon: "\ue034"; label: "Pause";   btnColor: Colours.tPalette.m3surfaceContainerHigh; btnTextColor: Colours.palette.m3onSurface; implicitWidth: 48; implicitHeight: 40; visible: root._live; onClicked: TimerService.pause() }
        TimerControlButton { icon: "\ue5cd"; label: "Stop";    btnColor: Qt.alpha(Colours.palette.m3error, 0.12); btnTextColor: Colours.palette.m3error; implicitWidth: 48; implicitHeight: 40; visible: root._active; onClicked: TimerService.stop() }
    }
}
