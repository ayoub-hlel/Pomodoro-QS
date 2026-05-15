pragma Singleton
import QtQuick
import qs.services

/**
 * TestData — Optimized State Management.
 * Uses ListModel for surgical UI updates to prevent "Global Refresh" flicker.
 */
QtObject {
    id: root

    property var list: null
    property bool ready: false

    // ── The Source of Truth for the UI ─────────────────────────────
    readonly property ListModel tasksModel: ListModel {}

    function seed() {
        var existing = TaskDB.getLists();
        if (existing.length > 0) {
            root.list = existing[0];
            loadFromDB();
            return;
        }

        root.list = TaskDB.createList("Default", "#6750A4", "checklist");
        
        var t1 = TaskDB.createTask(root.list.id, "Designing the new Shell Interface", 3600);
        TaskDB.setSubtask(t1.id, "Define color tokens", 1);
        TaskDB.setSubtask(t1.id, "Build component mockups", 1);
        TaskDB.setSubtask(t1.id, "Implement TaskCard layout", 1);
        TaskDB.setSubtask(t1.id, "QA review", 1);

        var t2 = TaskDB.createTask(root.list.id, "Write Project Documentation", 5400);
        TaskDB.setSubtask(t2.id, "API reference", 1);
        TaskDB.setSubtask(t2.id, "User guide", 0);

        loadFromDB();
    }

    // ── Load / Sync Logic ──────────────────────────────────────────
    function loadFromDB() {
        if (!root.list) {
            var lists = TaskDB.getLists();
            if (lists.length > 0) root.list = lists[0];
            else return;
        }

        tasksModel.clear();
        var rows = TaskDB.getTasks(root.list.id, true);
        for (var i = 0; i < rows.length; i++) {
            var t = rows[i];
            // Embed subtasks directly in the model for atomic updates
            t.subtasksList = TaskDB.getSubtasks(t.id);
            tasksModel.append(t);
        }
        root.ready = true;
    }

    /**
     * Surgical Update: Only updates the specific task that changed.
     * Prevents other cards from re-binding or flickering.
     */
    function syncTask(taskId) {
        for (var i = 0; i < tasksModel.count; i++) {
            if (tasksModel.get(i).id === taskId) {
                // Fetch fresh data from DB
                var freshTasks = TaskDB.getTasks(root.list.id, true);
                var freshData = null;
                for (var j = 0; j < freshTasks.length; j++) {
                    if (freshTasks[j].id === taskId) {
                        freshData = freshTasks[j];
                        break;
                    }
                }
                
                if (freshData) {
                    freshData.subtasksList = TaskDB.getSubtasks(taskId);
                    tasksModel.set(i, freshData);
                }
                return;
            }
        }
    }

    Component.onCompleted: Qt.callLater(seed)
}
