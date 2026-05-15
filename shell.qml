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

    // ── Global Popups ──────────────────────────────────────────
    SchedulingPopup { id: schedPopup }
    
    Popup {
        id: expandedMenu
        width: 350; height: 400
        background: Rectangle { color: Colours.tPalette.m3surfaceContainer; radius: 16 }
        
        property int activeTaskId: 0
        
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 16
            spacing: 12
            
            RowLayout {
                spacing: 8
                Button { text: "Schedule"; onClicked: { expandedMenu.close(); schedPopup.taskId = expandedMenu.activeTaskId; schedPopup.open(); } }
                Button { text: "Notes"; onClicked: { notesStack.currentIndex = 0; } }
                Button { text: "Subtasks"; onClicked: { notesStack.currentIndex = 1; } }
                Item { Layout.fillWidth: true }
                Button { 
                    text: "Delete"; 
                    palette.button: Colours.palette.m3error; 
                    palette.buttonText: "white";
                    onClicked: { 
                        TaskDB.updateTaskField(expandedMenu.activeTaskId, "is_archived", 1); 
                        TestData.syncTask(expandedMenu.activeTaskId);
                        expandedMenu.close(); 
                    } 
                }
            }

            StackLayout {
                id: notesStack
                Layout.fillWidth: true; Layout.fillHeight: true
                NotesPanel { taskId: expandedMenu.activeTaskId }
                SubtaskPanel { 
                    taskId: expandedMenu.activeTaskId
                    subtasks: expandedMenu.activeTaskId > 0 ? TestData.getTask(expandedMenu.activeTaskId).subtasksList : []
                }
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
            }

            BoardColumn {
                title: "This Week"; accentColor: Colours.palette.m3tertiary; model: TestData.weekModel
                onTaskToggled: (id) => { TaskDB.toggleTaskCompletion(id); TestData.syncTask(id); }
                onTaskMoved: (id, dir) => win.moveTask(id, dir)
                onTaskMenu: (id, p) => { expandedMenu.activeTaskId = id; expandedMenu.open(); }
            }

            BoardColumn {
                title: "Today"; accentColor: Colours.palette.m3primary; model: TestData.todayModel
                onTaskToggled: (id) => { TaskDB.toggleTaskCompletion(id); TestData.syncTask(id); }
                onTaskMoved: (id, dir) => win.moveTask(id, dir)
                onTaskMenu: (id, p) => { expandedMenu.activeTaskId = id; expandedMenu.open(); }
                
                // Done Zone is at the bottom of Today
                ColumnLayout {
                    Layout.fillWidth: true; visible: TestData.doneModel.count > 0; spacing: 8
                    Rectangle { Layout.fillWidth: true; height: 1; color: Colours.palette.m3outlineVariant }
                    Text { text: "DONE"; font.pixelSize: 10; font.bold: true; color: Colours.palette.m3success; Layout.leftMargin: 8 }
                    Repeater {
                        model: TestData.doneModel
                        delegate: TaskCard {
                            Layout.fillWidth: true; task: model; isActive: false
                            onToggleComplete: (id) => { TaskDB.toggleTaskCompletion(id); TestData.syncTask(id); }
                        }
                    }
                }
            }
        }
    }
}
