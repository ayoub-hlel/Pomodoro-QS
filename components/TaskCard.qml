import QtQuick
import QtQuick.Layouts

import qs.services

/**
 * TaskCard — Blitzit-style task card with inline editing.
 *
 * Shows: checkbox → title (click-to-edit) → play/pause button
 * Bottom row: EST · subtask progress · tracked time
 *
 * AXIOM_COLOR: All colors from Colours.palette / Colours.tPalette.
 * AXIOM_ANIM:  Behaviors on color/opacity.
 */
Item {
    id: root

    property var task: ({})
    property var subtasks: []
    property bool isActive: false

    signal toggleComplete(int taskId)
    signal startFocus(int taskId, string taskName)
    signal deleteRequested(int taskId)
    signal editRequested(int taskId)
    signal subtaskToggled(int taskId, int subtaskId, bool isCompleted)

    readonly property var _t: task || {}
    readonly property bool _done: _t.is_completed === 1 || _t.is_completed === true
    readonly property int _est: _t.estimate || 0
    readonly property int _actual: _t.actual_time || 0
    readonly property int _taskId: _t.id || 0

    readonly property int _subCount: {
        if (!subtasks) return 0
        return subtasks.count !== undefined ? subtasks.count : (subtasks.length || 0)
    }
    readonly property int _doneCount: {
        var c = 0
        for (var i = 0; i < root._subCount; i++) {
            var item = subtasks.get !== undefined ? subtasks.get(i) : subtasks[i]
            if (item && (item.is_completed === 1 || item.is_completed === true)) c++
        }
        return c
    }
    readonly property real _subFrac: root._subCount > 0 ? root._doneCount / root._subCount : 0
    // ── Drag state (placeholder for Stage 4 full DnD) ────────────
    property bool _dragHover: false

    /** Whether the play button should show "pause" (same task, active timer) */
    readonly property bool _sameTask: TimerService.activeTaskId === root._taskId
    readonly property bool _timerLive: _sameTask && (TimerService.state === "running" || TimerService.state === "break")
    readonly property bool _timerPaused: _sameTask && TimerService.state === "paused"

    implicitHeight: mainCol.implicitHeight + 24

    // ── Card background ────────────────────────────────────────────
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 12
        color: root.isActive
            ? Qt.alpha(Colours.palette.m3primary, 0.08)
            : Colours.tPalette.m3surfaceContainerLow
        Behavior on color { ColorAnimation { duration: 300 } }

        Rectangle {
            anchors.fill: parent; radius: 13; anchors.margins: -1
            color: "transparent"; border.width: 1
            border.color: root.isActive
                ? Qt.alpha(Colours.palette.m3primary, 0.3)
                : Qt.alpha(Colours.palette.m3outlineVariant, 0.15)
            Behavior on border.color { ColorAnimation { duration: 300 } }
        }
    }

    // ── Main content ───────────────────────────────────────────────
    ColumnLayout {
        id: mainCol
        anchors { fill: parent; margins: 12 }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // ── Drag Handle ─────────────────────────────────────────
            Item {
                Layout.preferredWidth: 20; Layout.preferredHeight: 20; Layout.alignment: Qt.AlignTop
                Layout.topMargin: 2
                visible: !root._done
                opacity: root._dragHover ? 0.6 : 0.25
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "\ue945"  // drag_indicator
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                    color: Colours.palette.m3onSurfaceVariant
                }

                MouseArea {
                    id: dragHandleArea
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.SizeAllCursor
                    hoverEnabled: true
                    property bool _hovered: false
                    onEntered: { root._dragHover = true; _hovered = true; }
                    onExited: { root._dragHover = false; _hovered = false; }
                }
            }

            // ── Checkbox ────────────────────────────────────────────
            Item {
                Layout.preferredWidth: 22; Layout.preferredHeight: 22; Layout.alignment: Qt.AlignTop
                Rectangle {
                    anchors.fill: parent; radius: 11
                    color: root._done ? Colours.palette.m3primary : "transparent"
                    border.width: root._done ? 0 : 2
                    border.color: Colours.palette.m3outline
                    Text {
                        anchors.centerIn: parent
                        text: "\u2713"; color: Colours.palette.m3onPrimary
                        font.pixelSize: 13; visible: root._done
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleComplete(root._taskId)
                }
            }

            // ── Title (click to edit) ───────────────────────────────
            TextInput {
                id: titleInput
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                text: root._t.name || ""
                font.pixelSize: 14; font.family: "Rubik"
                color: root._done ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                opacity: root._done ? 0.55 : 1.0
                readOnly: true
                wrapMode: TextInput.Wrap
                clip: true
                height: Math.min(contentHeight, 40)
                Behavior on color { ColorAnimation { duration: 300 } }
                Behavior on opacity { NumberAnimation { duration: 300 } }

                // Enable editing on double-click
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    acceptedButtons: Qt.LeftButton
                    onDoubleClicked: {
                        if (!root._done) {
                            titleInput.readOnly = false;
                            titleInput.forceActiveFocus();
                            titleInput.selectAll();
                        }
                    }
                }

                // Save on Enter or focus lost
                onAccepted: _finishEdit()
                onActiveFocusChanged: {
                    if (!activeFocus && !readOnly) _finishEdit()
                }

                function _finishEdit() {
                    readOnly = true;
                    if (text !== root._t.name) {
                        TaskDB.updateTaskField(root._taskId, "name", text);
                        TestData.syncTask(root._taskId);
                    }
                }
            }

            // ── Play / Pause / Resume button ────────────────────────
            Item {
                Layout.preferredWidth: 36; Layout.preferredHeight: 36; Layout.alignment: Qt.AlignTop
                visible: !root._done
                Rectangle {
                    anchors.fill: parent; radius: 18
                    color: root._timerLive
                        ? Colours.palette.m3primary
                        : (root._timerPaused ? Colours.palette.m3tertiary : Colours.palette.m3primaryContainer)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Text {
                        anchors.centerIn: parent
                        text: root._timerLive ? "\ue034" : (root._timerPaused ? "\ue037" : "\ue037")
                        font.family: "Material Symbols Rounded"; font.pixelSize: 20
                        color: (root._timerLive || root._timerPaused)
                            ? Colours.palette.m3onPrimary
                            : Colours.palette.m3onPrimaryContainer
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root._timerLive)
                            TimerService.pause()
                        else if (root._timerPaused)
                            TimerService.resume()
                        else
                            root.startFocus(root._taskId, root._t.name || "")
                    }
                }
            }
        }

        // ── Bottom row: EST · subtask progress · tracked time ──────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 60
            spacing: 4
            visible: root._est > 0 || root._actual > 0 || root._subCount > 0

            // EST (time estimate)
            Text {
                text: root._est > 0 ? Format.duration(root._est) + " est" : ""
                font.pixelSize: 11; font.family: "CaskaydiaCove NF"
                color: Colours.palette.m3onSurfaceVariant; opacity: 0.7
                visible: root._est > 0
            }

            Text {
                text: "\u00b7"
                font.pixelSize: 11; color: Colours.palette.m3onSurfaceVariant; opacity: 0.3
                visible: root._est > 0 && root._subCount > 0
            }

            // Subtask progress
            Text {
                text: root._subCount > 0 ? root._doneCount + "/" + root._subCount + " done" : ""
                font.pixelSize: 11; font.family: "CaskaydiaCove NF"
                color: Colours.palette.m3onSurfaceVariant; opacity: 0.6
                visible: root._subCount > 0
            }

            Item { Layout.fillWidth: true }

            // Time tracked
            Text {
                text: root._actual > 0 ? Format.duration(root._actual) + " tracked" : ""
                font.pixelSize: 11; font.family: "CaskaydiaCove NF"
                color: Colours.palette.m3primary; opacity: 0.7
                visible: root._actual > 0
            }
        }
    }

    // ── Subtle subtask progress line at bottom ─────────────────────
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 3; radius: 1.5
        visible: root._subCount > 0
        color: Colours.tPalette.m3surfaceContainerHigh
        Rectangle {
            width: root._subFrac * parent.width; height: parent.height; radius: 1.5
            color: root._done ? Colours.palette.m3success : Colours.palette.m3primary
            Behavior on width { NumberAnimation { duration: 300 } }
        }
    }
}
