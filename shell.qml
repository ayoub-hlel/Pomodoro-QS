import QtQuick
import QtQuick.Layouts

import Quickshell
import qs.services
import "./components"

Window {
    id: win
    width: 480; height: 720
    visible: true; title: "Pomodoro-QS"
    color: Colours.palette.m3background

    // ── Keyboard shortcuts ──────────────────────────────────────
    Shortcut { sequence: "Space"; onActivated: _handleSpace(); }
    Shortcut { sequence: "Escape"; onActivated: TimerService.stop(); }
    Shortcut { sequence: "Return"; onActivated: _completeActiveTask(); }

    function _handleSpace() {
        switch (TimerService.state) {
            case "idle":
            case "done":
                // Start timer for the first Today task, if any
                if (TestData.todayModel.count > 0) {
                    var t = TestData.todayModel.get(0);
                    TimerService.start(t.id, t.name || "");
                }
                break;
            case "running":
            case "break":
                TimerService.pause();
                break;
            case "paused":
                TimerService.resume();
                break;
        }
    }

    function _completeActiveTask() {
        if (TimerService.activeTaskId > 0) {
            TaskDB.toggleTaskCompletion(TimerService.activeTaskId);
            TestData.syncTask(TimerService.activeTaskId);
        }
    }

    // ── Timer persistence ─────────────────────────────────────
    // Save tracked time when the timer requests it (on pause/stop/finish/switch)
    Connections {
        target: TimerService
        function onSaveRequested(taskId, elapsedSeconds) {
            if (taskId > 0 && elapsedSeconds > 0) {
                TaskDB.addActualTime(taskId, elapsedSeconds);
                TestData.syncTask(taskId);
            }
        }
    }

    // Periodic auto-save every 30 seconds while running
    Timer {
        id: _autoSave
        interval: 30000
        repeat: true
        running: TimerService.state === "running" || TimerService.state === "break"
        onTriggered: {
            if (TimerService.activeTaskId > 0 && TimerService.elapsed > 0) {
                TaskDB.addActualTime(TimerService.activeTaskId, TimerService.elapsed);
                TestData.syncTask(TimerService.activeTaskId);
            }
        }
    }

    // ── Active task data (looked up from TestData models) ──────
    property var activeTaskData: TimerService.activeTaskId > 0
        ? TestData.getTask(TimerService.activeTaskId) : null

    // ══════════════════════════════════════════════════════════
    // UI LAYOUT
    // ══════════════════════════════════════════════════════════

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight + 40; clip: true

        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 16

            // ── Header Row ──────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "Pomodoro-QS"
                    font.pixelSize: 24; font.family: "Rubik"; font.bold: true
                    color: Colours.palette.m3onBackground
                    Layout.fillWidth: true
                }

                // "N TASKS FOR TODAY" badge
                Text {
                    text: TestData.todayTotal + " TASKS FOR TODAY"
                    font.pixelSize: 10; font.letterSpacing: 1.5
                    font.family: "Rubik"; color: Colours.palette.m3primary
                    visible: TestData.ready && TestData.todayTotal > 0
                    Layout.alignment: Qt.AlignBottom
                }

                // "+" add task button
                Rectangle {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    radius: 16
                    color: Colours.palette.m3primaryContainer
                    Text {
                        anchors.centerIn: parent
                        text: "+"; font.pixelSize: 20; font.bold: true
                        font.family: "Rubik"
                        color: Colours.palette.m3onPrimaryContainer
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: _createTask()
                    }
                }
            }

            // ── Focus Timer Strip ───────────────────────────────────
            TimerDisplay {
                Layout.fillWidth: true
                visible: TimerService.state !== "idle"
                height: visible ? implicitHeight : 0
                Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }

            // ── Ongoing Task Section (visible when timer is active) ─
            ColumnLayout {
                Layout.fillWidth: true
                visible: TimerService.state !== "idle" && TimerService.state !== "done"
                    && TimerService.activeTaskId > 0

                SectionHeader {
                    title: "Ongoing"
                    icon: "\ue8df"
                    count: 1
                    accentColor: Colours.palette.m3primary
                }

                TaskCard {
                    Layout.fillWidth: true
                    task: activeTaskData || {}
                    subtasks: activeTaskData ? activeTaskData.subtasksList || [] : []
                    isActive: true

                    onToggleComplete: function(taskId) {
                        TaskDB.toggleTaskCompletion(taskId);
                        TestData.syncTask(taskId);
                    }
                    onStartFocus: function(taskId, taskName) {
                        TimerService.start(taskId, taskName);
                    }
                    onSubtaskToggled: function(taskId, subtaskId, isCompleted) {
                        TaskDB.updateSubtask(subtaskId, { is_completed: isCompleted ? 1 : 0 });
                        TestData.syncTask(taskId);
                    }
                }
            }

            // ── Today Section ───────────────────────────────────────
            SectionHeader {
                title: "Today"
                icon: "\ue8df"
                count: TestData.todayTotal
                doneCount: TestData.todayProgress
                accentColor: Colours.palette.m3primary
            }

            Repeater {
                model: TestData.todayModel
                delegate: TaskCard {
                    Layout.fillWidth: true
                    task: model
                    subtasks: model.subtasksList
                    isActive: model.id === TimerService.activeTaskId

                    onToggleComplete: function(taskId) {
                        TaskDB.toggleTaskCompletion(taskId);
                        TestData.syncTask(taskId);
                    }
                    onStartFocus: function(taskId, taskName) {
                        TimerService.start(taskId, taskName);
                    }
                    onSubtaskToggled: function(taskId, subtaskId, isCompleted) {
                        TaskDB.updateSubtask(subtaskId, { is_completed: isCompleted ? 1 : 0 });
                        TestData.syncTask(taskId);
                    }
                }
            }

            // ── This Week Section ───────────────────────────────────
            SectionHeader {
                title: "This Week"
                icon: "\ue878"
                count: TestData.weekTotal
                doneCount: TestData.weekProgress
                accentColor: Colours.palette.m3tertiary
            }

            Repeater {
                model: TestData.weekModel
                delegate: TaskCard {
                    Layout.fillWidth: true
                    task: model
                    subtasks: model.subtasksList
                    isActive: false

                    onToggleComplete: function(taskId) {
                        TaskDB.toggleTaskCompletion(taskId);
                        TestData.syncTask(taskId);
                    }
                    onStartFocus: function(taskId, taskName) {
                        TimerService.start(taskId, taskName);
                    }
                    onSubtaskToggled: function(taskId, subtaskId, isCompleted) {
                        TaskDB.updateSubtask(subtaskId, { is_completed: isCompleted ? 1 : 0 });
                        TestData.syncTask(taskId);
                    }
                }
            }

            // ── Backlog Section ─────────────────────────────────────
            SectionHeader {
                title: "Backlog"
                icon: "\ue2c7"
                count: TestData.backlogTotal
                doneCount: TestData.backlogProgress
                accentColor: Colours.palette.m3onSurfaceVariant
            }

            Repeater {
                model: TestData.backlogModel
                delegate: TaskCard {
                    Layout.fillWidth: true
                    task: model
                    subtasks: model.subtasksList
                    isActive: false

                    onToggleComplete: function(taskId) {
                        TaskDB.toggleTaskCompletion(taskId);
                        TestData.syncTask(taskId);
                    }
                    onStartFocus: function(taskId, taskName) {
                        TimerService.start(taskId, taskName);
                    }
                    onSubtaskToggled: function(taskId, subtaskId, isCompleted) {
                        TaskDB.updateSubtask(subtaskId, { is_completed: isCompleted ? 1 : 0 });
                        TestData.syncTask(taskId);
                    }
                }
            }

            // ── Done Section (completed tasks) ──────────────────────
            SectionHeader {
                title: "Done"
                icon: "\ue86c"
                count: TestData.doneModel.count
                accentColor: Colours.palette.m3success
            }

            Repeater {
                model: TestData.doneModel
                delegate: TaskCard {
                    Layout.fillWidth: true
                    task: model
                    subtasks: model.subtasksList
                    isActive: false

                    onToggleComplete: function(taskId) {
                        TaskDB.toggleTaskCompletion(taskId);
                        TestData.syncTask(taskId);
                    }
                    onStartFocus: function(taskId, taskName) {
                        TimerService.start(taskId, taskName);
                    }
                    onSubtaskToggled: function(taskId, subtaskId, isCompleted) {
                        TaskDB.updateSubtask(subtaskId, { is_completed: isCompleted ? 1 : 0 });
                        TestData.syncTask(taskId);
                    }
                }
            }

            // ── Bottom spacer ───────────────────────────────────────
            Item { Layout.preferredHeight: 20 }
        }
    }

    // ── Task Creation ─────────────────────────────────────────────
    function _createTask() {
        if (!TestData.list) return;
        var now = Math.floor(Date.now() / 1000);
        var today = TestData._todayStart();
        var task = TaskDB.createTask(TestData.list.id, "New task");
        TaskDB.updateTaskField(task.id, "scheduled_at", today);
        TestData.loadFromDB();

        // Scroll to bottom where the new task appears
        // (Flickable.contentHeight animation is implicit)
    }
}
