import QtQuick
import QtQuick.Layouts
import qs.services
import "."

ColumnLayout {
    id: root
    property int taskId: 0
    property var subtasks: []

    spacing: 8

    // ── Creation Input ──────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 6
        color: Colours.tPalette.m3surfaceContainerHigh
        
        TextInput {
            id: subInput; anchors.fill: parent; anchors.margins: 6
            font.pixelSize: 13; font.family: "Rubik"; color: Colours.palette.m3onSurface
            onAccepted: {
                if (text.trim() === "") return;
                TaskDB.createSubtask(root.taskId, text);
                TestData.syncTask(root.taskId);
                text = "";
            }
        }
    }

    // ── Subtask List ─────────────────────────────────────────────
    Repeater {
        model: root.subtasks
        delegate: RowLayout {
            Layout.fillWidth: true; spacing: 8
            
            // Checkbox
            Rectangle {
                width: 18; height: 18; radius: 9
                border.width: model.is_completed ? 0 : 2
                border.color: Colours.palette.m3outline
                color: model.is_completed ? Colours.palette.m3primary : "transparent"
                Text { anchors.centerIn: parent; text: "\u2713"; color: "white"; font.pixelSize: 11; visible: model.is_completed }
                MouseArea { anchors.fill: parent; onClicked: {
                    TaskDB.updateSubtask(model.id, "is_completed", model.is_completed ? 0 : 1);
                    TestData.syncTask(root.taskId);
                }}
            }

            // Title
            TextInput {
                Layout.fillWidth: true; text: model.name || ""
                font.pixelSize: 13; font.family: "Rubik"
                color: model.is_completed ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                onAccepted: {
                    TaskDB.updateSubtask(model.id, "name", text);
                    TestData.syncTask(root.taskId);
                }
            }

            // Reorder / Delete
            IconBtn { icon: "\ue5d8"; size: 24; color: Colours.palette.m3outline; onClicked: console.log("Up") }
            IconBtn { icon: "\ue5db"; size: 24; color: Colours.palette.m3outline; onClicked: console.log("Down") }
            IconBtn { icon: "\ue872"; size: 24; color: Colours.palette.m3error; onClicked: {
                TaskDB.deleteSubtask(model.id);
                TestData.syncTask(root.taskId);
            }}
        }
    }
}
