pragma Singleton
import QtQuick
import qs.services

/**
 * TestData — The Central Classification Engine.
 *
 * Models:
 *   backlogModel — >1 week out or unscheduled
 *   weekModel    — Scheduled for current Mon-Sun (excluding today)
 *   todayModel   — Scheduled for today or Overdue
 *   doneModel    — Completed tasks (shown in 'Done' zone)
 */
QtObject {
    id: root

    // ── Active State ─────────────────────────────────────────────
    property int activeListId: 0 // 0 = All Lists View
    property var list: null      // Reference for metadata
    property bool ready: false

    // ── Three-Column Models ──────────────────────────────────────
    readonly property ListModel backlogModel: ListModel {}
    readonly property ListModel weekModel: ListModel {}
    readonly property ListModel todayModel: ListModel {}
    readonly property ListModel doneModel: ListModel {}

    // ── Date Math ────────────────────────────────────────────────
    function _todayStart() {
        let d = new Date(); d.setHours(0,0,0,0);
        return Math.floor(d.getTime() / 1000);
    }
    function _todayEnd() {
        let d = new Date(); d.setHours(23,59,59,999);
        return Math.floor(d.getTime() / 1000);
    }
    function _weekEnd() {
        let d = new Date();
        let day = d.getDay(); // 0 is Sun
        let diff = (day === 0 ? 0 : 7 - day); // days to Sun
        let sun = new Date(d.getTime() + diff * 86400 * 1000);
        sun.setHours(23,59,59,999);
        return Math.floor(sun.getTime() / 1000);
    }

    // ── Classification Logic ─────────────────────────────────────
    function getColumnFor(task) {
        if (!task) return "backlog";
        if (task.is_completed) return "done";
        
        let s = task.scheduled_at || 0;
        let todayEnd = _todayEnd();
        let weekEnd = _weekEnd();

        if (s === 0) return "backlog";
        if (s <= todayEnd) return "today"; // Includes Overdue
        if (s <= weekEnd) return "week";
        return "backlog";
    }

    // ── Lookup a task by ID across all models ───────────────────
    function getTask(taskId) {
        if (!taskId) return null;
        let models = [todayModel, weekModel, backlogModel, doneModel];
        for (let m = 0; m < models.length; m++) {
            for (let i = 0; i < models[m].count; i++) {
                if (models[m].get(i).id === taskId)
                    return models[m].get(i);
            }
        }
        return null;
    }

    // ── Model Sync ───────────────────────────────────────────────
    function loadFromDB() {
        backlogModel.clear();
        weekModel.clear();
        todayModel.clear();
        doneModel.clear();

        // Fetch all tasks for activeListId (0 fetches all across lists)
        let rows = TaskDB.getTasks(activeListId, true);
        for (let i = 0; i < rows.length; i++) {
            let t = rows[i];
            t.subtasksList = TaskDB.getSubtasks(t.id);
            
            let col = getColumnFor(t);
            if (col === "today") todayModel.append(t);
            else if (col === "week") weekModel.append(t);
            else if (col === "done") doneModel.append(t);
            else backlogModel.append(t);
        }
        
        // If specific list, fetch list metadata
        if (activeListId > 0) {
            let lists = TaskDB.getLists();
            for (let j = 0; j < lists.length; j++) {
                if (lists[j].id === activeListId) {
                    root.list = lists[j];
                    break;
                }
            }
        } else {
            root.list = { name: "All Lists", color: "#6750A4" };
        }
        
        root.ready = true;
    }

    function syncTask(taskId) {
        if (!taskId) return;
        
        // 1. Remove from all current models (thoroughly)
        let models = [todayModel, weekModel, backlogModel, doneModel];
        for (let m = 0; m < models.length; m++) {
            for (let i = models[m].count - 1; i >= 0; i--) {
                if (models[m].get(i).id === taskId) {
                    models[m].remove(i, 1);
                }
            }
        }

        // 2. Fetch fresh data
        let rows = TaskDB.getTasks(0, true); // Search all to be safe
        let fresh = null;
        for (let j = 0; j < rows.length; j++) {
            if (rows[j].id === taskId) { fresh = rows[j]; break; }
        }
        if (!fresh) return;

        // 3. Filter by current activeListView if needed
        if (activeListId !== 0 && fresh.list_id !== activeListId) return;

        // 4. Re-classify
        fresh.subtasksList = TaskDB.getSubtasks(taskId);
        let col = getColumnFor(fresh);
        if (col === "today") todayModel.append(fresh);
        else if (col === "week") weekModel.append(fresh);
        else if (col === "done") doneModel.append(fresh);
        else backlogModel.append(fresh);
    }

    // ── Seeding ──────────────────────────────────────────────────
    function seed() {
        let lists = TaskDB.getLists();
        if (lists.length === 0) {
            TaskDB.createList("Work", "#6750A4", "work");
            TaskDB.createList("Personal", "#2196F3", "person");
        }
        loadFromDB();
    }

    Component.onCompleted: seed()
}
