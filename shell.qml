import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import "./components"

Window {
    id: win
    width: 1300; height: 900
    visible: true; title: "Pomodoro-QS — The Board"
    color: Colours.palette.m3background

    property int _dragTaskId: 0
    property string _dragTitle: ""
    
    DragProxy {
        id: dragProxy
        visible: _dragTaskId > 0
        title: _dragTitle
        // Position is updated by the global tracker
    }

    // Positioning is now handled by the dragMove signals

    // ── Global Popups ──────────────────────────────────────────
    SchedulingPopup { id: schedPopup }
    
    Popup {
        id: expandedMenu
        width: 400; height: 500
        padding: 0; modal: true; focus: true
        anchors.centerIn: parent
        
        background: Rectangle { 
            color: Colours.tPalette.m3surfaceContainer; radius: 20
            border.width: 1; border.color: Qt.alpha(Colours.palette.m3outline, 0.1)
        }
        
        property int activeTaskId: 0
        
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 20
            spacing: 16
            
            Text {
                property var activeTask: expandedMenu.activeTaskId > 0 ? TestData.getTask(expandedMenu.activeTaskId) : null
                text: activeTask ? activeTask.name : "Task Details"
                font.pixelSize: 18; font.weight: Font.Bold; color: Colours.palette.m3onSurface
                Layout.fillWidth: true; elide: Text.ElideRight
            }

            RowLayout {
                spacing: 4
                Button { 
                    text: "Notes"; flat: notesStack.currentIndex !== 0; 
                    onClicked: notesStack.currentIndex = 0 
                }
                Button { 
                    text: "Subtasks"; flat: notesStack.currentIndex !== 1; 
                    onClicked: notesStack.currentIndex = 1 
                }
                Item { Layout.fillWidth: true }
                IconBtn { 
                    icon: "\ue872"; size: 32; color: Colours.palette.m3error; 
                    onClicked: { 
                        let tid = expandedMenu.activeTaskId;
                        TaskDB.updateTaskField(tid, "is_archived", 1); 
                        TestData.syncTask(tid);
                        expandedMenu.activeTaskId = 0;
                        expandedMenu.close(); 
                    } 
                }
            }

            StackLayout {
                id: notesStack
                Layout.fillWidth: true; Layout.fillHeight: true
                property var activeTask: expandedMenu.activeTaskId > 0 ? TestData.getTask(expandedMenu.activeTaskId) : null
                
                NotesPanel { 
                    taskId: expandedMenu.activeTaskId
                    initialNotes: notesStack.activeTask ? notesStack.activeTask.notes : "" 
                }
                SubtaskPanel { 
                    taskId: expandedMenu.activeTaskId
                    subtasks: notesStack.activeTask ? notesStack.activeTask.subtasksList : []
                }
            }

            Button {
                text: "Schedule Task"; Layout.fillWidth: true; highlighted: true
                onClicked: { expandedMenu.close(); schedPopup.taskId = expandedMenu.activeTaskId; schedPopup.open(); }
            }
        }
    }

    // ── Celebration Popup ──────────────────────────────────────
    Popup {
        id: successPopup
        width: 380; height: 480
        modal: true; focus: true
        anchors.centerIn: parent
        visible: TestData.ready && TestData.todayModel.count === 0 && TestData.doneModel.count > 0
        
        background: Rectangle { 
            color: Colours.tPalette.m3surfaceContainer; radius: 24
            border.width: 1; border.color: Qt.alpha(Colours.palette.m3outline, 0.1)
        }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 24; spacing: 16
            
            Image {
                source: "file:///home/biyop/.gemini/antigravity/brain/b9662a04-92f6-4114-8b75-086fd50b3775/celebration_meme_success_1778926403172.png"
                Layout.preferredWidth: 200; Layout.preferredHeight: 200
                Layout.alignment: Qt.AlignCenter
                fillMode: Image.PreserveAspectFit
            }

            Text {
                text: "WELL DONE!"; font.pixelSize: 24; font.weight: Font.Black
                color: Colours.palette.m3primary; Layout.alignment: Qt.AlignCenter
            }

            Text {
                text: "You've crushed all your tasks for today. Your Obsidian vault is synced and up to date."; 
                font.pixelSize: 14; color: Colours.palette.m3onSurfaceVariant
                Layout.fillWidth: true; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
                opacity: 0.8
            }

            RowLayout {
                Layout.alignment: Qt.AlignCenter; spacing: 20
                ColumnLayout {
                    Text { text: TestData.doneModel.count; font.pixelSize: 20; font.bold: true; color: Colours.palette.m3onSurface; Layout.alignment: Qt.AlignCenter }
                    Text { text: "TASKS"; font.pixelSize: 10; color: Colours.palette.m3onSurfaceVariant; Layout.alignment: Qt.AlignCenter }
                }
                Rectangle { width: 1; height: 30; color: Colours.palette.m3outlineVariant }
                ColumnLayout {
                    Text { text: "100%"; font.pixelSize: 20; font.bold: true; color: Colours.palette.m3success; Layout.alignment: Qt.AlignCenter }
                    Text { text: "DONE"; font.pixelSize: 10; color: Colours.palette.m3onSurfaceVariant; Layout.alignment: Qt.AlignCenter }
                }
            }

            Button {
                text: "GO RELAX"; highlighted: true; Layout.fillWidth: true
                Layout.preferredHeight: 52
                onClicked: successPopup.close()
            }
        }
    }

    TaskAlert {
        id: dueAlert
        anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 24
        onDoNow: (id) => { TaskDB.updateTaskField(id, "scheduled_at", TestData._todayStart()); TestData.syncTask(id); dueTasks = []; }
        onDoLater: (id) => { dueTasks = []; }
    }

    // ── Timer state observer: Auto-open URLs from notes ──────────
    Connections {
        target: TimerService
        function onTimerStateChanged(newState) {
            if (newState === "running" && TimerService.activeTaskId > 0) {
                let task = TestData.getTask(TimerService.activeTaskId);
                if (task && task.notes) {
                    let urlRegex = /(https?:\/\/[^\s]+)/g;
                    let match;
                    while ((match = urlRegex.exec(task.notes)) !== null) {
                        Qt.openUrlExternally(match[0]);
                    }
                }
            }
        }
    }

    // ── Logic ────────────────────────────────────────────────────
    function moveTask(taskId, direction) {
        let t = TestData.getTask(taskId);
        let col = TestData.getColumnFor(t);
        let today = TestData._todayStart();
        let newTime = 0;

        if (direction === "right") {
            if (col === "backlog") newTime = today + 86400;
            else if (col === "week") newTime = today;
        } else {
            if (col === "today") newTime = today + 86400;
            else if (col === "week") newTime = 0;
        }

        TaskDB.updateTaskField(taskId, "scheduled_at", newTime);
        TestData.syncTask(taskId);
    }

    // Check for due tasks every minute
    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: {
            let today = TestData._todayStart();
            let tasks = TaskDB.getTasks(0, false);
            let due = [];
            for (let i=0; i<tasks.length; i++) {
                if (tasks[i].scheduled_at === today && !tasks[i].is_completed) due.push(tasks[i]);
            }
            if (due.length > 0) dueAlert.dueTasks = due;
        }
    }

    // ── UI Layout ───────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 24; spacing: 24

        RowLayout {
            Layout.fillWidth: true; spacing: 20
            ListSelector { Layout.alignment: Qt.AlignVCenter }
            Item { Layout.fillWidth: true }
            TimerDisplay { 
                Layout.preferredWidth: 350; 
                visible: TimerService.state !== "idle" || TestData.todayModel.count > 0
                onStartTriggered: {
                    if (TestData.todayModel.count > 0) {
                        let t = TestData.todayModel.get(0);
                        TimerService.start(t.id, t.name);
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 24

            BoardColumn {
                title: "Backlog"; accentColor: Colours.palette.m3onSurfaceVariant; model: TestData.backlogModel
                onTaskToggled: (id) => { TaskDB.toggleTaskCompletion(id); TestData.syncTask(id); }
                onTaskMoved: (id, dir) => win.moveTask(id, dir)
                onTaskMenu: (id, p) => { expandedMenu.activeTaskId = id; expandedMenu.open(); }
                onTaskDropped: (id) => { TaskDB.updateTaskField(id, "scheduled_at", 0); TestData.syncTask(id); }
                onDragStart: (id, title, pos) => { _dragTaskId = id; _dragTitle = title; dragProxy.x = pos.x - dragProxy.width/2; dragProxy.y = pos.y - dragProxy.height/2; }
                onDragMove: (pos) => { dragProxy.x = pos.x - dragProxy.width/2; dragProxy.y = pos.y - dragProxy.height/2; }
                onDragEnd: { _dragTaskId = 0; }
            }

            BoardColumn {
                title: "This Week"; accentColor: Colours.palette.m3tertiary; model: TestData.weekModel
                onTaskToggled: (id) => { TaskDB.toggleTaskCompletion(id); TestData.syncTask(id); }
                onTaskMoved: (id, dir) => win.moveTask(id, dir)
                onTaskMenu: (id, p) => { expandedMenu.activeTaskId = id; expandedMenu.open(); }
                onTaskDropped: (id) => { TaskDB.updateTaskField(id, "scheduled_at", TestData._todayStart() + 86400); TestData.syncTask(id); }
                onDragStart: (id, title, pos) => { _dragTaskId = id; _dragTitle = title; dragProxy.x = pos.x - dragProxy.width/2; dragProxy.y = pos.y - dragProxy.height/2; }
                onDragMove: (pos) => { dragProxy.x = pos.x - dragProxy.width/2; dragProxy.y = pos.y - dragProxy.height/2; }
                onDragEnd: { _dragTaskId = 0; }
            }

            BoardColumn {
                title: "Today"; accentColor: Colours.palette.m3primary; model: TestData.todayModel
                doneModel: TestData.doneModel; showBlitz: true
                onTaskToggled: (id) => { TaskDB.toggleTaskCompletion(id); TestData.syncTask(id); }
                onTaskMoved: (id, dir) => win.moveTask(id, dir)
                onTaskMenu: (id, p) => { expandedMenu.activeTaskId = id; expandedMenu.open(); }
                onTaskDropped: (id) => { TaskDB.updateTaskField(id, "scheduled_at", TestData._todayStart()); TestData.syncTask(id); }
                onDragStart: (id, title, pos) => { _dragTaskId = id; _dragTitle = title; dragProxy.x = pos.x - dragProxy.width/2; dragProxy.y = pos.y - dragProxy.height/2; }
                onDragMove: (pos) => { dragProxy.x = pos.x - dragProxy.width/2; dragProxy.y = pos.y - dragProxy.height/2; }
                onDragEnd: { _dragTaskId = 0; }
            }
        }
    }
}
