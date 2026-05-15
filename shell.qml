import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import "./components"

Window {
    id: win
    width: 480; height: 720
    visible: true; title: "Pomodoro-QS — Smart Logic Demo"
    color: Colours.palette.m3background

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight + 40; clip: true

        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 16

            Text {
                text: "Smart Task Logic"; font.pixelSize: 22; font.family: "Rubik"; font.bold: true
                color: Colours.palette.m3onBackground
            }

            TimerDisplay {
                Layout.fillWidth: true
                // compact: true  // uncomment for compact horizontal layout
            }

            Repeater {
                model: TestData.tasksModel
                delegate: TaskCard {
                    Layout.fillWidth: true
                    task: model // Bound to ListModel entry
                    subtasks: model.subtasksList // Atomic update via ListModel
                    isActive: index === 0

                    onToggleComplete: function(taskId) {
                        // Use Smart Toggle Logic
                        TaskDB.toggleTaskCompletion(taskId);
                        TestData.syncTask(taskId);
                    }

                    onStartFocus: function(taskId) {
                        // Start Pomodoro focus session for this task
                        TimerService.start(taskId);
                    }

                    onSubtaskToggled: function(taskId, subtaskId, isCompleted) {
                        // Use Integrity Observer Logic
                        TaskDB.updateSubtask(subtaskId, { is_completed: isCompleted ? 1 : 0 });
                        // Refresh the parent task to show new progress/completion
                        TestData.syncTask(taskId);
                    }
                }
            }
        }
    }
}
