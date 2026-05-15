import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import "./components"

Window {
    id: win
    width: 440
    height: 700
    visible: true
    title: "Pomodoro-QS — TaskCard Showcase"
    color: Colours.palette.m3background

    ColumnLayout {
        anchors {
            fill: parent
            margins: 20
        }
        spacing: 16

        // Title
        Text {
            text: "TaskCard Showcase"
            font.pixelSize: 22
            font.family: "Rubik"
            font.bold: true
            color: Colours.palette.m3onBackground
            Layout.bottomMargin: 8
        }

        // 1. Active task
        TaskCard {
            Layout.fillWidth: true
            isActive: true
            task: ({
                id: 1,
                name: "Designing the new Shell Interface",
                estimate: 3600,
                actual_time: 1200
            })
            onStartFocus: console.log("focus toggle:", taskId)
            onToggleComplete: console.log("toggle complete:", taskId)
        }

        // 2. Completed task
        TaskCard {
            Layout.fillWidth: true
            task: ({
                id: 2,
                name: "Write Project Documentation",
                is_completed: 1
            })
            onStartFocus: console.log("focus toggle:", taskId)
            onToggleComplete: console.log("toggle complete:", taskId)
        }

        // 3. Overdue task
        TaskCard {
            Layout.fillWidth: true
            task: ({
                id: 3,
                name: "Review PR #42",
                scheduled_at: Math.floor(Date.now() / 1000) - 86400
            })
            onStartFocus: console.log("focus toggle:", taskId)
            onToggleComplete: console.log("toggle complete:", taskId)
        }

        // 4. Task with subtasks + notes + URL
        TaskCard {
            Layout.fillWidth: true
            task: ({
                id: 4,
                name: "Feature Implementation",
                notes: "This has notes and a progress bar",
                url: "https://github.com/example/pr"
            })
            subtasks: [
                { is_completed: 1 },
                { is_completed: 1 },
                { is_completed: 0 }
            ]
            onStartFocus: console.log("focus toggle:", taskId)
            onToggleComplete: console.log("toggle complete:", taskId)
        }

        // 5. Compact mode
        TaskCard {
            Layout.fillWidth: true
            compact: true
            task: ({
                id: 5,
                name: "Compact mode example — minimised card"
            })
        }

        Item { Layout.fillHeight: true }
    }
}
