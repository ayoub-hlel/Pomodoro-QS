import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import "."

/**
 * BoardColumn — Wrapped in Item to support DropArea anchors correctly.
 */
Item {
    id: root

    // ── Properties ──────────────────────────────────────────────
    property string title: ""
    property ListModel model: null
    property ListModel doneModel: null
    property bool showBlitz: false
    property color accentColor: Colours.palette.m3primary
    
    readonly property real _progress: {
        let total = (model ? model.count : 0) + (doneModel ? doneModel.count : 0);
        if (total === 0) return 0;
        return (doneModel ? doneModel.count : 0) / total;
    }
    
    signal taskToggled(int id)
    signal taskMoved(int id, string dir)
    signal taskMenu(int id, point pos)
    signal taskDropped(int id)
    signal dragStart(int id, string title, point pos)
    signal dragMove(point pos)
    signal dragEnd()

    signal addTaskTop()
    signal addTaskBottom()

    onAddTaskTop: { root.isCreatingTask = true; }
    property bool isCreatingTask: false

    implicitWidth: 320
    Layout.fillHeight: true
    Layout.fillWidth: true
    Layout.preferredWidth: 320

    // ── Background ──────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent; radius: 12
        color: Colours.tPalette.m3surfaceContainerLow
        border.width: 1; border.color: Qt.alpha(Colours.palette.m3outline, 0.1)
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent; anchors.margins: 12
        spacing: 12

        // ── Progress Bar ──────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            visible: root.title === "Today" || root.title === "This Week"
            
            RowLayout {
                Text { 
                    text: "PROGRESS"; font.pixelSize: 10; font.weight: Font.Black; 
                    color: Colours.palette.m3onSurfaceVariant; opacity: 0.6 
                }
                Item { Layout.fillWidth: true }
                Text { 
                    text: Math.round(root._progress * 100) + "%"
                    font.pixelSize: 10; font.weight: Font.Bold; color: Colours.palette.m3primary 
                }
            }

            Rectangle {
                Layout.fillWidth: true; height: 6; radius: 3
                color: Colours.tPalette.m3surfaceContainerHigh
                
                Rectangle {
                    width: parent.width * root._progress; height: parent.height; radius: 3
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Colours.palette.m3primary }
                        GradientStop { position: 1.0; color: Colours.palette.m3tertiary }
                    }
                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                }
            }
        }

        // ── Header ──────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            Text {
                text: root.title
                font.pixelSize: 16; font.weight: Font.Bold
                color: Colours.palette.m3onBackground
                Layout.fillWidth: true
            }

            IconBtn {
                icon: "\ue145" // add
                size: 28; color: root.accentColor
                onClicked: root.addTaskTop()
            }
        }

        // ── Task List ───────────────────────────────────────────────
        ListView {
            id: listView
            Layout.fillWidth: true; Layout.fillHeight: true
            model: root.model
            spacing: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            
            // Transitions for smooth reordering/adding
            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 200 }
            }
            displaced: Transition {
                NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutQuad }
            }

            header: ColumnLayout {
                width: listView.width
                spacing: 8
                
                // ── Creation Input ───────────────────────────────────
                Rectangle {
                    id: topInputBox
                    Layout.fillWidth: true; height: root.isCreatingTask ? 44 : 0; radius: 8
                    color: Colours.tPalette.m3surfaceContainerHigh
                    visible: root.isCreatingTask
                    clip: true
                    
                    Behavior on height { NumberAnimation { duration: 200 } }
                    
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 8
                        TextInput {
                            id: topInput; Layout.fillWidth: true
                            font.pixelSize: 14; color: Colours.palette.m3onSurface
                            focus: topInputBox.visible
                            onAccepted: {
                                if (text.trim() === "") { topInputBox.visible = false; return; }
                                let t = TaskDB.createTask(TestData.activeListId, text);
                                if (root.title === "Today") TaskDB.updateTaskField(t.id, "scheduled_at", TestData._todayStart());
                                else if (root.title === "This Week") TaskDB.updateTaskField(t.id, "scheduled_at", TestData._todayStart() + 86400);
                                TestData.syncTask(t.id);
                                text = ""; root.isCreatingTask = false;
                            }
                            Keys.onEscapePressed: { text = ""; root.isCreatingTask = false; }
                        }
                    }
                    onVisibleChanged: if (visible) topInput.forceActiveFocus()
                }
            }

            delegate: TaskCard {
                width: listView.width
                task: model
                subtasks: model.subtasksList
                isActive: TimerService.activeTaskId === model.id
                
                onTaskToggled: (id) => root.taskToggled(id)
                onMoveColumn: (id, dir) => root.taskMoved(id, dir)
                onMenuRequested: (id, p) => root.taskMenu(id, p)
                onDragStart: (id, title, pos) => root.dragStart(id, title, pos)
                onDragMove: (pos) => root.dragMove(pos)
                onDragEnd: () => root.dragEnd()
                onEditTitle: (id, name) => {
                    TaskDB.updateTaskField(id, "name", name);
                    TestData.syncTask(id);
                }
            }

            footer: ColumnLayout {
                width: listView.width
                spacing: 8
                
                // ── Done Zone ──────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true; visible: root.doneModel && root.doneModel.count > 0; spacing: 4
                    Item { Layout.preferredHeight: 8 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Colours.palette.m3outlineVariant; opacity: 0.2 }
                    Text { 
                        text: "DONE"; font.pixelSize: 10; font.weight: Font.Black; 
                        color: Colours.palette.m3success; Layout.leftMargin: 4; opacity: 0.6
                    }
                    Repeater {
                        model: root.doneModel
                        delegate: TaskCard {
                            width: listView.width; task: model; isActive: false
                            onTaskToggled: (id) => root.taskToggled(id)
                            onDragStart: (id, title, pos) => root.dragStart(id, title, pos)
                            onDragMove: (pos) => root.dragMove(pos)
                            onDragEnd: () => root.dragEnd()
                        }
                    }
                }

                // ── Blitz Button ──────────────────────────────────────
                Button {
                    Layout.fillWidth: true; Layout.preferredHeight: 52
                    Layout.topMargin: 12
                    visible: root.showBlitz && root.model && root.model.count > 0 && TimerService.state === "idle"
                    
                    contentItem: RowLayout {
                        spacing: 8; Layout.alignment: Qt.AlignCenter
                        Text { text: "\ue037"; font.family: "Material Symbols Rounded"; font.pixelSize: 20; color: "white" }
                        Text { 
                            text: "BLITZ NOW"; font.pixelSize: 14; font.weight: Font.Black; 
                            font.letterSpacing: 2; color: "white" 
                        }
                    }

                    background: Rectangle {
                        radius: 12
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#FF5F6D" }
                            GradientStop { position: 1.0; color: "#FFC371" }
                        }
                    }
                    
                    onClicked: {
                        if (root.model.count > 0) {
                            let t = root.model.get(0);
                            TimerService.start(t.id, t.name);
                        }
                    }
                }
            }
        }
    }

    // ── Drop Area ───────────────────────────────────────────────
    DropArea {
        id: dropZone
        anchors.fill: parent
        keys: ["task"]
        onDropped: (drop) => {
            let tid = drop.getDataAsString("taskId") || (drop.mimeData && drop.mimeData["taskId"]);
            if (tid) {
                drop.accept();
                root.taskDropped(parseInt(tid));
            }
        }
    }

    Rectangle {
        anchors.fill: parent; radius: 12
        color: Qt.alpha(Colours.palette.m3primary, 0.05)
        border.width: 2; border.color: Colours.palette.m3primary
        visible: dropZone.containsDrag
    }
}
