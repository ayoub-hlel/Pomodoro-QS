pragma Singleton
import QtQuick
import QtQuick.LocalStorage

Item {
    id: root
    property var _db: null

    function run(cb, r = false) {
        if (r) _db.readTransaction(tx => { cb(tx); });
        else _db.transaction(tx => { tx.executeSql("PRAGMA foreign_keys = ON;"); cb(tx); });
    }

    Component.onCompleted: {
        try {
            _db = LocalStorage.openDatabaseSync("PomodoroQS", "1.0", "TaskDB", 5000000);
            run(tx => {
                tx.executeSql("CREATE TABLE IF NOT EXISTS lists (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, color TEXT, icon TEXT DEFAULT 'checklist');");
                tx.executeSql("CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, list_id INTEGER NOT NULL, name TEXT NOT NULL, estimate INTEGER DEFAULT 0, actual_time INTEGER DEFAULT 0, scheduled_at INTEGER DEFAULT 0, snoozed_until INTEGER DEFAULT 0, position INTEGER NOT NULL, is_completed INTEGER DEFAULT 0, is_archived INTEGER DEFAULT 0, created_at INTEGER NOT NULL);");
                // Hardened Subtasks: Added completed_at for chronological undo
                tx.executeSql("CREATE TABLE IF NOT EXISTS subtasks (id INTEGER PRIMARY KEY AUTOINCREMENT, task_id INTEGER NOT NULL, name TEXT NOT NULL, is_completed INTEGER DEFAULT 0, completed_at INTEGER DEFAULT 0);");
                tx.executeSql("CREATE TABLE IF NOT EXISTS sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, task_id INTEGER NOT NULL, started_at INTEGER NOT NULL, ended_at INTEGER DEFAULT 0, duration INTEGER DEFAULT 0, mode TEXT NOT NULL);");
                
                // Migration: Attempt to add completed_at if it doesn't exist
                try { tx.executeSql("ALTER TABLE subtasks ADD COLUMN completed_at INTEGER DEFAULT 0;"); } catch(e) {}
            });
        } catch (e) { console.error("TaskDB:", e); }
    }

    // ── Smart Toggle Logic (Chronological) ─────────────────────────
    function toggleTaskCompletion(taskId) {
        run(tx => {
            let t = tx.executeSql("SELECT is_completed FROM tasks WHERE id = ?", [taskId]).rows.item(0);
            let isCurrentlyDone = t.is_completed === 1;

            if (isCurrentlyDone) {
                // CHRONOLOGICAL UNDO: Find the subtask that was finished LAST in time
                let subtasks = tx.executeSql("SELECT id FROM subtasks WHERE task_id = ? AND is_completed = 1 ORDER BY completed_at DESC, id DESC", [taskId]);
                if (subtasks.rows.length > 0) {
                    tx.executeSql("UPDATE subtasks SET is_completed = 0, completed_at = 0 WHERE id = ?", [subtasks.rows.item(0).id]);
                    tx.executeSql("UPDATE tasks SET is_completed = 0 WHERE id = ?", [taskId]);
                } else {
                    tx.executeSql("UPDATE tasks SET is_completed = 0 WHERE id = ?", [taskId]);
                }
            } else {
                // Force complete everything (and stamp them all with current time)
                let now = Math.floor(Date.now() / 1000);
                tx.executeSql("UPDATE subtasks SET is_completed = 1, completed_at = ? WHERE task_id = ?", [now, taskId]);
                tx.executeSql("UPDATE tasks SET is_completed = 1 WHERE id = ?", [taskId]);
            }
        });
    }

    // ── Subtask Mutation with Temporal Stamping ────────────────────
    function updateSubtask(subtaskId, fields) {
        let k = Object.keys(fields); if (!k.length) return;
        run(tx => {
            // If marking as completed, add temporal stamp
            if (fields.is_completed === 1) {
                fields.completed_at = Math.floor(Date.now() / 1000);
                k.push("completed_at");
            } else if (fields.is_completed === 0) {
                fields.completed_at = 0;
                k.push("completed_at");
            }

            tx.executeSql(`UPDATE subtasks SET ${k.map(x => `${x} = ?`).join(", ")} WHERE id = ?`, [...Object.values(fields), subtaskId]);
            
            let taskId = tx.executeSql("SELECT task_id FROM subtasks WHERE id = ?", [subtaskId]).rows.item(0).task_id;
            let total = tx.executeSql("SELECT COUNT(*) as c FROM subtasks WHERE task_id = ?", [taskId]).rows.item(0).c;
            let done = tx.executeSql("SELECT COUNT(*) as c FROM subtasks WHERE task_id = ? AND is_completed = 1", [taskId]).rows.item(0).c;
            
            tx.executeSql("UPDATE tasks SET is_completed = ? WHERE id = ?", [(total > 0 && total === done) ? 1 : 0, taskId]);
        });
    }

    // Boilerplate
    function getTasks(l, a) { let r = []; run(tx => { let rs = tx.executeSql(`SELECT * FROM tasks WHERE list_id = ? ${a ? "" : "AND is_completed = 0"} ORDER BY position`, [l]); for (let i = 0; i < rs.rows.length; i++) r.push(rs.rows.item(i)); }, true); return r; }
    function getSubtasks(t) { let r = []; run(tx => { let rs = tx.executeSql("SELECT * FROM subtasks WHERE task_id = ?", [t]); for (let i = 0; i < rs.rows.length; i++) r.push(rs.rows.item(i)); }, true); return r; }
    function createList(n, c, i) { let r; run(tx => { tx.executeSql("INSERT INTO lists (name, color, icon) VALUES (?, ?, ?)", [n, c, i]); r = tx.executeSql("SELECT * FROM lists WHERE id = last_insert_rowid()").rows.item(0); }); return r; }
    /** Whitelist of updatable fields — prevents SQL injection */
    readonly property var _taskFields: ["name", "estimate", "actual_time", "scheduled_at", "snoozed_until", "position", "is_completed", "is_archived"]
    function updateTaskField(id, field, value) {
        if (_taskFields.indexOf(field) < 0) {
            console.error("TaskDB: blocked update of unknown field '" + field + "'");
            return;
        }
        run(tx => { tx.executeSql("UPDATE tasks SET " + field + " = ? WHERE id = ?", [value, id]); });
    }
    /** Accumulate tracked time without overwriting */
    function addActualTime(taskId, seconds) {
        if (!taskId || !seconds || seconds <= 0) return;
        run(tx => {
            tx.executeSql("UPDATE tasks SET actual_time = actual_time + ? WHERE id = ?", [Math.floor(seconds), taskId]);
        });
    }
    function createTask(l, n, e) { let r; run(tx => { let p = tx.executeSql("SELECT COUNT(*) as c FROM tasks WHERE list_id = ?", [l]).rows.item(0).c; tx.executeSql("INSERT INTO tasks (list_id, name, estimate, position, created_at) VALUES (?, ?, ?, ?, ?)", [l, n, e || 0, p, Math.floor(Date.now()/1000)]); r = tx.executeSql("SELECT * FROM tasks WHERE id = last_insert_rowid()").rows.item(0); }); return r; }
    function setSubtask(t, n, c) { run(tx => tx.executeSql("INSERT INTO subtasks (task_id, name, is_completed) VALUES (?, ?, ?)", [t, n, c])); }
    function getLists() { let r = []; run(tx => { let rs = tx.executeSql("SELECT * FROM lists"); for (let i = 0; i < rs.rows.length; i++) r.push(rs.rows.item(i)); }, true); return r; }
}
