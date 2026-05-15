import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import "./components"

Window {
    id: win
    width: 480
    height: 720
    visible: true
    title: "Pomodoro-QS — Component Showcase"
    color: Colours.palette.m3background

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight + 40
        clip: true

        ColumnLayout {
            id: column
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 20
            }
            spacing: 16

            // ── Title ──
            Text {
                text: "TaskCard + SubtaskRow"
                font.pixelSize: 22
                font.family: "Rubik"
                font.bold: true
                color: Colours.palette.m3onBackground
                Layout.bottomMargin: 2
            }

            // ── DB info line ──
            Text {
                text: TestData.ready
                    ? TestData.list.name + " \u00b7 " + TestData.tasks.length + " tasks"
                    : "Loading database\u2026"
                font.pixelSize: 13
                font.family: "Rubik"
                color: Colours.palette.m3onSurfaceVariant
                visible: true
                Layout.bottomMargin: 8
            }

            // ── Loading indicator ──
            Text {
                id: loadingMsg
                text: "Seeding test database\u2026"
                font.pixelSize: 14
                font.family: "Rubik"
                color: Colours.palette.m3onSurfaceVariant
                visible: !TestData.ready
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 40
            }

            // ── Task Cards from DB ──
            Repeater {
                model: TestData.tasks

                delegate: TaskCard {
                    id: card
                    Layout.fillWidth: true
                    Layout.topMargin: 4

                    required property var modelData
                    required property int index

                    task: modelData

                    subtasks: TestData.subtasksForTask(modelData.id)

                    // Last card gets active highlight for demo
                    isActive: index === 0

                    // Compact mode for short tasks
                    compact: modelData.name.length < 20 && index > 2

                    onToggleComplete: {
                        console.log("toggle complete:", taskId)
                        var newVal = task.is_completed ? 0 : 1
                        TaskDB.updateTask(taskId, { is_completed: newVal })
                        TestData.loadFromDB()
                    }

                    onStartFocus: console.log("focus toggle:", taskId)

                    onSubtaskToggled: {
                        console.log("subtask", subtaskId, "of task", taskId, "→", isCompleted)
                        TaskDB.updateSubtask(subtaskId, { is_completed: isCompleted ? 1 : 0 })
                        // Reload subtask data for this task
                        var updated = TaskDB.getSubtasks(taskId)
                        // Trigger re-evaluation by re-loading full data
                        TestData.loadFromDB()
                    }
                }
            }

            // ── Footer ──
            Text {
                text: TestData.ready
                    ? "Data from TaskDB \u00b7 Interactive \u00b7 Try toggling"
                    : ""
                font.pixelSize: 12
                font.family: "Rubik"
                color: Colours.palette.m3onSurfaceVariant
                visible: TestData.ready
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
            }

            Item { Layout.fillHeight: true }
        }
    }
}
