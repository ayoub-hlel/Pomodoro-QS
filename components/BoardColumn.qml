import QtQuick
import QtQuick.Layouts
import qs.services
import "."

ColumnLayout {
    id: root

    // ── Properties ──────────────────────────────────────────────
    property string title: ""
    property ListModel model: null
    property color accentColor: Colours.palette.m3primary
    
    signal addTaskTop()
    signal addTaskBottom()
    signal taskToggled(int id)
    signal taskMoved(int id, string dir)
    signal taskMenu(int id, point pos)

    onAddTaskTop: { topInputBox.visible = true; topInput.forceActiveFocus(); }
    onAddTaskBottom: { bottomInputBox.visible = true; bottomInput.forceActiveFocus(); }

    spacing: 12
    Layout.fillHeight: true
    Layout.fillWidth: true
    Layout.preferredWidth: 320

    // ── Header ──────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        
        Text {
            text: root.title
            font.pixelSize: 18; font.family: "Rubik"; font.bold: true
            color: Colours.palette.m3onBackground
            Layout.fillWidth: true
        }

        IconBtn {
            icon: "\ue145" // add
            size: 32; color: root.accentColor
            onClicked: root.addTaskTop()
        }
    }

    // ── Task List ───────────────────────────────────────────────
    Flickable {
        Layout.fillWidth: true; Layout.fillHeight: true
        contentHeight: listCol.implicitHeight; clip: true
        
        ColumnLayout {
            id: listCol
            anchors { left: parent.left; right: parent.right }
            spacing: 8

            // ── Top Creation Input ────────────────────────────────
            Rectangle {
                id: topInputBox
                Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 8
                color: Colours.tPalette.m3surfaceContainerHigh
                visible: false
                
                TextInput {
                    id: topInput; anchors.fill: parent; anchors.margins: 8
                    font.pixelSize: 14; font.family: "Rubik"; color: Colours.palette.m3onSurface
                    onAccepted: {
                        let t = TaskDB.createTask(TestData.activeListId, text);
                        if (root.title === "Today") TaskDB.updateTaskField(t.id, "scheduled_at", TestData._todayStart());
                        else if (root.title === "This Week") TaskDB.updateTaskField(t.id, "scheduled_at", TestData._todayStart() + 86400);
                        TestData.syncTask(t.id);
                        text = ""; parent.visible = false;
                    }
                }
            }

            Repeater {
                model: root.model
                delegate: TaskCard {
                    Layout.fillWidth: true
                    task: model
                    subtasks: model.subtasksList
                    isActive: TimerService.activeTaskId === model.id
                    
                    onToggleComplete: (id) => root.taskToggled(id)
                    onMoveColumn: (id, dir) => root.taskMoved(id, dir)
                    onMenuRequested: (id, p) => root.taskMenu(id, p)
                    onEditTitle: (id, name) => {
                        TaskDB.updateTaskField(id, "name", name);
                        TestData.syncTask(id);
                    }
                }
            }

            // ── Bottom Creation Input ─────────────────────────────
            Rectangle {
                id: bottomInputBox
                Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 8
                color: Colours.tPalette.m3surfaceContainerHigh
                visible: false
                
                TextInput {
                    id: bottomInput; anchors.fill: parent; anchors.margins: 8
                    font.pixelSize: 14; font.family: "Rubik"; color: Colours.palette.m3onSurface
                    onAccepted: {
                        let t = TaskDB.createTask(TestData.activeListId, text);
                        if (root.title === "Today") TaskDB.updateTaskField(t.id, "scheduled_at", TestData._todayStart());
                        else if (root.title === "This Week") TaskDB.updateTaskField(t.id, "scheduled_at", TestData._todayStart() + 86400);
                        TestData.syncTask(t.id);
                        text = ""; parent.visible = false;
                    }
                }
            }

            // ── Bottom Add Button ─────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 48
                color: "transparent"; border.width: 1; 
                border.color: Qt.alpha(root.accentColor, 0.3); radius: 12
                
                RowLayout {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: "+"; color: root.accentColor; font.bold: true }
                    Text { 
                        text: "ADD TASK"; color: root.accentColor; 
                        font.pixelSize: 11; font.letterSpacing: 1.2; font.bold: true 
                    }
                }
                
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.addTaskBottom()
                }
            }
        }
    }
}
