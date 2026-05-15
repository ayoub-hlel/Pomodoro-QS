import QtQuick
import QtQuick.Layouts
import qs.services

/**
 * TimerDisplay — Focus Mode strip.
 *
 * Shows: circular donut progress → HH:MM:SS countdown → task name → controls.
 * Hidden when idle (shell.qml manages visibility).
 *
 * AXIOM_COLOR: All colors from Colours.palette / Colours.tPalette.
 * AXIOM_ANIM:  Behaviors on all visual properties.
 * AXIOM_TIME:  Uses shared Format service.
 */
Item {
    id: root
    signal startTriggered()

    // ── Derived State ──────────────────────────────────────────────
    readonly property string _label: {
        switch (TimerService.state) {
            case "running": return "FOCUS"
            case "paused":  return "PAUSED"
            case "break":   return "BREAK"
            case "done":    return "DONE!"
            default:        return "READY"
        }
    }

    readonly property color _stateColor: {
        switch (TimerService.state) {
            case "running": return Colours.palette.m3primary
            case "paused":  return Colours.palette.m3onSurfaceVariant
            case "break":   return Colours.palette.m3tertiary
            case "done":    return Colours.palette.m3success
            default:        return Colours.palette.m3primary
        }
    }

    readonly property color _bgColor: {
        switch (TimerService.state) {
            case "running": return Qt.alpha(Colours.palette.m3primary, 0.08)
            case "break":   return Qt.alpha(Colours.palette.m3tertiary, 0.08)
            case "done":    return Qt.alpha(Colours.palette.m3success, 0.08)
            default:        return Colours.tPalette.m3surfaceContainerLow
        }
    }

    readonly property int _totalDuration: TimerService.state === "break"
        ? TimerService.breakDuration : TimerService.workDuration

    readonly property real _progress: {
        if (TimerService.state === "idle" || _totalDuration <= 0) return 1.0
        return Math.min(1.0, Math.max(0, TimerService.timeLeft / _totalDuration))
    }

    readonly property bool _live: TimerService.state === "running" || TimerService.state === "break"
    readonly property bool _active: TimerService.state !== "idle"

    implicitHeight: 96

    // ══════════════════════════════════════════════════════════════

    // ── Background ───────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 16
        color: root._bgColor
        Behavior on color { ColorAnimation { duration: 300 } }
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
        spacing: 16

        // ── Circular Progress (Canvas donut) ────────────────────
        Item {
            Layout.preferredWidth: 64; Layout.preferredHeight: 64
            visible: root._active

            Canvas {
                id: circle
                anchors.centerIn: parent
                width: 64; height: 64

                property color arcColor: root._stateColor
                property color trackColor: Qt.alpha(root._stateColor, 0.15)

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    // Track circle
                    ctx.beginPath();
                    ctx.arc(32, 32, 28, 0, 2 * Math.PI);
                    ctx.strokeStyle = trackColor;
                    ctx.lineWidth = 4;
                    ctx.stroke();

                    // Progress arc (clockwise from 12 o'clock)
                    if (root._progress > 0) {
                        ctx.beginPath();
                        ctx.arc(32, 32, 28,
                            -Math.PI / 2,
                            -Math.PI / 2 + 2 * Math.PI * root._progress);
                        ctx.strokeStyle = arcColor;
                        ctx.lineWidth = 4;
                        ctx.lineCap = "round";
                        ctx.stroke();
                    }
                }

                // Re-render when progress or colors change
                Connections {
                    target: root
                    function on_ProgressChanged() { circle.requestPaint(); }
                    function on_StateColorChanged() { circle.arcColor = root._stateColor; circle.requestPaint(); }
                }
                Component.onCompleted: requestPaint()
            }

            // Center label
            Text {
                anchors.centerIn: parent
                text: root._label
                font.pixelSize: 9; font.letterSpacing: 1.5
                font.family: "Rubik"; font.bold: true
                color: root._stateColor
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }

        // ── Time & Task Info ─────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            // HH:MM:SS countdown
            Text {
                text: Format.fullTimer(TimerService.timeLeft)
                font.pixelSize: 36; font.family: "CaskaydiaCove NF"; font.weight: Font.Bold
                color: TimerService.state === "paused"
                    ? Qt.alpha(Colours.palette.m3onSurface, 0.4)
                    : Colours.palette.m3onSurface
                Behavior on color { ColorAnimation { duration: 300 } }
            }

            // Task name
            Text {
                text: {
                    if (TimerService.activeTaskName)
                        return TimerService.activeTaskName
                    if (TimerService.state === "done") return "Session complete!"
                    return ""
                }
                font.pixelSize: 13; font.family: "Rubik"
                color: root._stateColor; opacity: 0.8
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 300 } }
            }

            // Elapsed counter
            Text {
                text: root._active ? "+" + Format.fullTimer(TimerService.elapsed) : ""
                font.pixelSize: 11; font.family: "CaskaydiaCove NF"
                color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.5)
            }
        }

        // ── Controls ────────────────────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 8

            TimerControlButton {
                icon: "\ue037"; label: "Start Focus"
                btnColor: Colours.palette.m3primary; btnTextColor: Colours.palette.m3onPrimary
                implicitWidth: 120; implicitHeight: 52; btnRadius: 26
                visible: TimerService.state === "idle" || TimerService.state === "done"
                onClicked: {
                    if (TimerService.state === "idle") root.startTriggered();
                    else TimerService.start();
                }
            }

            TimerControlButton {
                icon: "\ue037"; label: ""
                btnColor: Colours.palette.m3primary; btnTextColor: Colours.palette.m3onPrimary
                implicitWidth: 52; implicitHeight: 52; btnRadius: 26
                visible: TimerService.state === "paused"
                onClicked: TimerService.resume()
            }

            TimerControlButton {
                icon: "\ue034"; label: ""
                btnColor: Colours.tPalette.m3surfaceContainerHigh
                btnTextColor: Colours.palette.m3onSurface
                implicitWidth: 52; implicitHeight: 52; btnRadius: 26
                visible: root._live
                onClicked: TimerService.pause()
            }

            TimerControlButton {
                icon: "\ue5cd"; label: ""
                btnColor: Qt.alpha(Colours.palette.m3error, 0.12)
                btnTextColor: Colours.palette.m3error
                implicitWidth: 40; implicitHeight: 40; btnRadius: 20
                visible: root._active
                onClicked: TimerService.stop()
            }
        }
    }
}
