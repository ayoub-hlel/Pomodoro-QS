pragma Singleton
import QtQuick
import qs.services

/**
 * TestData — State Management with Blitzit-style 3-column layout + Done section.
 *
 * Models:
 *   todayModel    — incomplete tasks scheduled for today
 *   weekModel     — incomplete tasks scheduled for this week (Mon-Sun)
 *   backlogModel  — incomplete tasks beyond this week or unscheduled
 *   doneModel     — all completed tasks
 *
 * Column classification based on scheduled_at timestamp.
 */
QtObject {
    id: root

    property var list: null
    property bool ready: false

    // ── Column Models ────────────────────────────────────────────
    readonly property ListModel todayModel: ListModel {}
    readonly property ListModel weekModel: ListModel {}
    readonly property ListModel backlogModel: ListModel {}
    readonly property ListModel doneModel: ListModel {}

    // ── Progress Counts ──────────────────────────────────────────
    readonly property int todayProgress: root._countProgress(todayModel)
    readonly property int weekProgress: root._countProgress(weekModel)
    readonly property int backlogProgress: root._countProgress(backlogModel)
    readonly property int todayTotal: todayModel.count
    readonly property int weekTotal: weekModel.count
    readonly property int backlogTotal: backlogModel.count

    function _countProgress(model) {
        var done = 0;
        for (var i = 0; i < model.count; i++) {
            var t = model.get(i);
            if (t.is_completed === 1 || t.is_completed === true) done++;
        }
        return done;
    }

    // ── Date Helpers ─────────────────────────────────────────────
    function _todayStart() {
        var d = new Date();
        d.setHours(0, 0, 0, 0);
        return Math.floor(d.getTime() / 1000);
    }

    function _weekStart() {
        var d = new Date();
        var day = d.getDay();
        var diff = d.getDate() - day + (day === 0 ? -6 : 1);
        var mon = new Date(d.setDate(diff));
        mon.setHours(0, 0, 0, 0);
        return Math.floor(mon.getTime() / 1000);
    }

    // ── Seed ─────────────────────────────────────────────────────
    function seed() {
        var existing = TaskDB.getLists();
        if (existing.length > 0) {
            root.list = existing[0];
            loadFromDB();
            return;
        }

        root.list = TaskDB.createList("Default", "#6750A4", "checklist");

        var now = Math.floor(Date.now() / 1000);
        var today = root._todayStart();
        var weekStart = root._weekStart();
        var weekEnd = weekStart + 7 * 86400;

        // ── Today's tasks ─────────────────────────────────────────
        var t1 = TaskDB.createTask(root.list.id, "Designing the new Shell Interface", 3600);
        TaskDB.updateTaskField(t1.id, "scheduled_at", today);
        TaskDB.setSubtask(t1.id, "Define color tokens", 1);
        TaskDB.setSubtask(t1.id, "Build component mockups", 1);
        TaskDB.setSubtask(t1.id, "Implement TaskCard layout", 1);
        TaskDB.setSubtask(t1.id, "QA review", 0);

        var t2 = TaskDB.createTask(root.list.id, "Write Project Documentation", 5400);
        TaskDB.updateTaskField(t2.id, "scheduled_at", today);
        TaskDB.setSubtask(t2.id, "API reference", 1);
        TaskDB.setSubtask(t2.id, "User guide", 0);

        // ── This Week tasks ───────────────────────────────────────
        var t3 = TaskDB.createTask(root.list.id, "Review Q3 Roadmap", 1800);
        TaskDB.updateTaskField(t3.id, "scheduled_at", today + 86400);

        var t4 = TaskDB.createTask(root.list.id, "Refactor DB Layer", 7200);
        TaskDB.updateTaskField(t4.id, "scheduled_at", weekStart + 3 * 86400);

        // ── Backlog tasks ─────────────────────────────────────────
        TaskDB.createTask(root.list.id, "Research new UI Framework", 10800);
        // no scheduled_at = backlog

        var t6 = TaskDB.createTask(root.list.id, "Plan Q4 Feature Set", 2700);
        TaskDB.updateTaskField(t6.id, "scheduled_at", weekEnd + 3 * 86400);

        TaskDB.createTask(root.list.id, "Optimize Database Queries", 4500);
        // no scheduled_at = backlog

        loadFromDB();
    }

    // ── Column Classification ─────────────────────────────────────
    function _columnFor(task) {
        if (!task || !task.scheduled_at || task.scheduled_at <= 0) return "backlog";
        var s = task.scheduled_at;
        var today = root._todayStart();
        var weekStart = root._weekStart();
        var weekEnd = weekStart + 7 * 86400;

        if (s < today + 86400) return "today";     // today or overdue
        if (s < weekEnd) return "week";             // this week
        return "backlog";                           // beyond this week
    }

    // ── Lookup a task by ID across all models ───────────────────
    function getTask(taskId) {
        if (!taskId) return null;
        var models = [todayModel, weekModel, backlogModel, doneModel];
        for (var m = 0; m < models.length; m++) {
            for (var i = 0; i < models[m].count; i++) {
                if (models[m].get(i).id === taskId)
                    return models[m].get(i);
            }
        }
        return null;
    }

    // ── Load / Reload ────────────────────────────────────────────
    function loadFromDB() {
        if (!root.list) {
            var lists = TaskDB.getLists();
            if (lists.length > 0) root.list = lists[0];
            else return;
        }

        todayModel.clear();
        weekModel.clear();
        backlogModel.clear();
        doneModel.clear();

        var rows = TaskDB.getTasks(root.list.id, true);
        for (var i = 0; i < rows.length; i++) {
            var t = rows[i];
            t.subtasksList = TaskDB.getSubtasks(t.id);

            // Completed tasks go to doneModel regardless of schedule
            if (t.is_completed === 1 || t.is_completed === true) {
                doneModel.append(t);
                continue;
            }

            // Incomplete: classify into column
            var col = root._columnFor(t);
            if (col === "today") todayModel.append(t);
            else if (col === "week") weekModel.append(t);
            else backlogModel.append(t);
        }
        root.ready = true;
    }

    /**
     * Surgical Update: find a task, re-classify, move between models.
     */
    function syncTask(taskId) {
        if (!taskId || !root.list) return;

        // Remove from all models first
        var models = [todayModel, weekModel, backlogModel, doneModel];
        for (var m = 0; m < models.length; m++) {
            for (var i = 0; i < models[m].count; i++) {
                if (models[m].get(i).id === taskId) {
                    models[m].remove(i, 1);
                    break;
                }
            }
        }

        // Fetch fresh data
        var freshTasks = TaskDB.getTasks(root.list.id, true);
        var freshData = null;
        for (var j = 0; j < freshTasks.length; j++) {
            if (freshTasks[j].id === taskId) {
                freshData = freshTasks[j];
                break;
            }
        }
        if (!freshData) return;

        freshData.subtasksList = TaskDB.getSubtasks(taskId);

        // Re-classify and append
        if (freshData.is_completed === 1 || freshData.is_completed === true) {
            doneModel.append(freshData);
        } else {
            var col = root._columnFor(freshData);
            if (col === "today") todayModel.append(freshData);
            else if (col === "week") weekModel.append(freshData);
            else backlogModel.append(freshData);
        }
    }

    Component.onCompleted: Qt.callLater(seed)
}
