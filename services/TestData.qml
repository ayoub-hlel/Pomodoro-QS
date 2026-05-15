pragma Singleton
import QtQuick
import qs.services

/**
 * TestData — Seeds and exposes test data from TaskDB for UI development.
 *
 * Idempotent: only seeds if no lists exist. Subsequent runs load existing data.
 * Pure data layer: no UI declarations, no presentation logic, no hex values.
 * Follows AXIOM_DB: data flows up to shell.qml, not down to TaskCard.
 *
 * Usage:
 *   import qs.services
 *   // Bind to TestData.tasks, TestData.subtasksForTask(id)
 */
QtObject {
    id: root

    // ── Public Properties ──────────────────────────────────────────

    /** All tasks loaded from DB */
    property var tasks: []

    /** Map of taskId → subtask array — populated by loadFromDB() */
    property var subtasksMap: ({})

    /** The first list (or null) — for single-list showcase */
    property var list: null

    /** True after seed/load completes */
    property bool ready: false

    // ── Seed Data ──────────────────────────────────────────────────
    function seed() {
        // Check if already seeded — idempotent
        var existing = TaskDB.getLists()
        if (existing.length > 0) {
            root.list = existing[0]
            loadFromDB()
            return
        }

        // ── Create the list ──
        root.list = TaskDB.createList("Default", "#6750A4", "checklist")
        if (!root.list) {
            console.error("TestData: Failed to create list")
            return
        }

        // ── Task 1: In-progress with 5 subtasks ──
        var t1 = TaskDB.createTask(root.list.id, "Designing the new Shell Interface", 3600)
        TaskDB.updateTask(t1.id, { actual_time: 1200 })
        TaskDB.setSubtask(t1.id, "Create wireframes", 1)
        TaskDB.setSubtask(t1.id, "Define color tokens", 1)
        TaskDB.setSubtask(t1.id, "Build component mockups", 0)
        TaskDB.setSubtask(t1.id, "Implement TaskCard layout", 0)
        TaskDB.setSubtask(t1.id, "QA review", 0)

        // ── Task 2: Completed task with 3 subtasks ──
        var t2 = TaskDB.createTask(root.list.id, "Write Project Documentation", 5400)
        TaskDB.updateTask(t2.id, { actual_time: 4800, is_completed: 1 })
        TaskDB.setSubtask(t2.id, "API reference", 1)
        TaskDB.setSubtask(t2.id, "User guide", 1)
        TaskDB.setSubtask(t2.id, "Architecture overview", 0)

        // ── Task 3: No subtasks, with notes ──
        var t3 = TaskDB.createTask(root.list.id, "Quick note — no subtasks", 0)
        // notes and url aren't in DB schema — they're transient UI properties

        // ── Task 4: Compact card candidate — with 2 subtasks ──
        var t4 = TaskDB.createTask(root.list.id, "Deploy to staging", 0)
        TaskDB.setSubtask(t4.id, "Build", 1)
        TaskDB.setSubtask(t4.id, "Run migrations", 0)

        // ── Task 5: Snoozed task with 4 subtasks ──
        var t5 = TaskDB.createTask(root.list.id, "Refactor database layer", 7200)
        TaskDB.updateTask(t5.id, {
            actual_time: 3600,
            snoozed_until: Math.floor(Date.now() / 1000) + 3600
        })
        TaskDB.setSubtask(t5.id, "Extract query builder", 1)
        TaskDB.setSubtask(t5.id, "Write migration scripts", 1)
        TaskDB.setSubtask(t5.id, "Update repositories", 1)
        TaskDB.setSubtask(t5.id, "Add integration tests", 0)

        loadFromDB()
    }

    // ── Load from DB ───────────────────────────────────────────────
    function loadFromDB() {
        var allTasks = []
        var map = ({})

        if (!root.list) {
            var lists = TaskDB.getLists()
            if (lists.length > 0) root.list = lists[0]
            else return
        }

        var rows = TaskDB.getTasks(root.list.id, true)
        for (var i = 0; i < rows.length; i++) {
            var t = rows[i]
            allTasks.push(t)
            map[t.id] = TaskDB.getSubtasks(t.id)
        }

        root.tasks = allTasks
        root.subtasksMap = map
        root.ready = true
    }

    // ── Helper: get subtasks for a given task ID ───────────────────
    function subtasksForTask(taskId) {
        if (!root.ready) return []
        return root.subtasksMap[taskId] || []
    }

    // ── Initialize ─────────────────────────────────────────────────
    // Use Qt.callLater so TaskDB's own Component.onCompleted runs first
    Component.onCompleted: Qt.callLater(seed)
}
