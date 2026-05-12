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
                tx.executeSql("CREATE TABLE IF NOT EXISTS subtasks (id INTEGER PRIMARY KEY AUTOINCREMENT, task_id INTEGER NOT NULL, name TEXT NOT NULL, is_completed INTEGER DEFAULT 0);");
                tx.executeSql("CREATE TABLE IF NOT EXISTS sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, task_id INTEGER NOT NULL, started_at INTEGER NOT NULL, ended_at INTEGER DEFAULT 0, duration INTEGER DEFAULT 0, mode TEXT NOT NULL);");
                tx.executeSql("CREATE INDEX IF NOT EXISTS idx_tasks_list ON tasks(list_id);");
            });
        } catch (e) { console.error("TaskDB:", e); }
    }
    function clearAll() { run(tx => { tx.executeSql("DELETE FROM sessions"); tx.executeSql("DELETE FROM subtasks"); tx.executeSql("DELETE FROM tasks"); tx.executeSql("DELETE FROM lists"); }); }
    function createList(n, c = "", i = "checklist") {
        let r; run(tx => {
            if (!n) throw new Error("Name required");
            tx.executeSql("INSERT INTO lists (name, color, icon) VALUES (?, ?, ?)", [n, c, i]);
            r = tx.executeSql("SELECT * FROM lists WHERE id = last_insert_rowid()").rows.item(0);
        }); return r;
    }
    function getLists() {
        let r = []; run(tx => {
            let rs = tx.executeSql("SELECT * FROM lists");
            for (let i = 0; i < rs.rows.length; i++) r.push(rs.rows.item(i));
        }, true); return r;
    }
    function deleteList(id) {
        run(tx => {
            tx.executeSql("DELETE FROM sessions WHERE task_id IN (SELECT id FROM tasks WHERE list_id = ?)", [id]);
            tx.executeSql("DELETE FROM subtasks WHERE task_id IN (SELECT id FROM tasks WHERE list_id = ?)", [id]);
            tx.executeSql("DELETE FROM tasks WHERE list_id = ?", [id]);
            tx.executeSql("DELETE FROM lists WHERE id = ?", [id]);
        });
    }
    function createTask(l, n, e = 0) {
        let r; run(tx => {
            if (tx.executeSql("SELECT 1 FROM lists WHERE id = ?", [l]).rows.length === 0) throw new Error("List not found");
            let p = tx.executeSql("SELECT COUNT(*) as c FROM tasks WHERE list_id = ?", [l]).rows.item(0).c;
            tx.executeSql("INSERT INTO tasks (list_id, name, estimate, position, created_at) VALUES (?, ?, ?, ?, ?)", [l, n, e, p, Math.floor(Date.now()/1000)]);
            r = tx.executeSql("SELECT * FROM tasks WHERE id = last_insert_rowid()").rows.item(0);
        }); return r;
    }
    function getTasks(l, a = false) {
        let r = []; run(tx => {
            let rs = tx.executeSql(`SELECT * FROM tasks WHERE list_id = ? ${a ? "" : "AND is_completed = 0"} ORDER BY position`, [l]);
            for (let i = 0; i < rs.rows.length; i++) r.push(rs.rows.item(i));
        }, true); return r;
    }
    function updateTask(id, f) {
        let k = Object.keys(f); if (!k.length) return;
        run(tx => tx.executeSql(`UPDATE tasks SET ${k.map(x => `${x} = ?`).join(", ")} WHERE id = ?`, [...Object.values(f), id]));
    }
    function deleteTask(id) {
        run(tx => {
            tx.executeSql("DELETE FROM sessions WHERE task_id = ?", [id]);
            tx.executeSql("DELETE FROM subtasks WHERE task_id = ?", [id]);
            tx.executeSql("DELETE FROM tasks WHERE id = ?", [id]);
        });
    }
    function setSubtask(t, n, c = 0) {
        run(tx => {
            if (tx.executeSql("SELECT 1 FROM tasks WHERE id = ?", [t]).rows.length === 0) throw new Error("Task not found");
            tx.executeSql("INSERT INTO subtasks (task_id, name, is_completed) VALUES (?, ?, ?)", [t, n, c]);
        });
    }
    function getSubtasks(t) {
        let r = []; run(tx => {
            let rs = tx.executeSql("SELECT * FROM subtasks WHERE task_id = ?", [t]);
            for (let i = 0; i < rs.rows.length; i++) r.push(rs.rows.item(i));
        }, true); return r;
    }
    function updateSubtask(id, f) {
        let k = Object.keys(f); if (!k.length) return;
        run(tx => tx.executeSql(`UPDATE subtasks SET ${k.map(x => `${x} = ?`).join(", ")} WHERE id = ?`, [...Object.values(f), id]));
    }
    function deleteSubtask(id) { run(tx => tx.executeSql("DELETE FROM subtasks WHERE id = ?", [id])); }
    function startSession(t, m) {
        let r; run(tx => {
            if (tx.executeSql("SELECT 1 FROM tasks WHERE id = ?", [t]).rows.length === 0) throw new Error("Task not found");
            tx.executeSql("INSERT INTO sessions (task_id, started_at, mode) VALUES (?, ?, ?)", [t, Math.floor(Date.now()/1000), m]);
            r = tx.executeSql("SELECT * FROM sessions WHERE id = last_insert_rowid()").rows.item(0);
        }); return r;
    }
    function endSession(id, d) {
        run(tx => {
            tx.executeSql("UPDATE sessions SET ended_at = ?, duration = ? WHERE id = ?", [Math.floor(Date.now()/1000), d, id]);
            tx.executeSql("UPDATE tasks SET actual_time = actual_time + ? WHERE id = (SELECT task_id FROM sessions WHERE id = ?)", [d, id]);
        });
    }
}
