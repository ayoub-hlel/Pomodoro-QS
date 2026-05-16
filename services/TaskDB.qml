pragma Singleton
import QtQuick
import QtQuick.LocalStorage

/**
 * TaskDB — Expanded Schema for Board-based Productivity.
 *
 * Tables:
 *   lists    — categories/projects
 *   tasks    — main units of work (inc. recurring parents)
 *   subtasks — nested items for a task
 *   sessions — record of time spent
 */
Item {
    id: root

    property var db: null

    function openDB() {
        if (db) return db;
        try {
            db = LocalStorage.openDatabaseSync("PomodoroQS_V2", "1.0", "Task Storage", 100000);
            db.transaction(tx => {
                // Lists: id, name, color, icon, type (checklist/board)
                tx.executeSql("CREATE TABLE IF NOT EXISTS lists (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, color TEXT, icon TEXT, type TEXT DEFAULT 'board')");
                
                // Tasks: expanded for scheduling and recurrence
                tx.executeSql(`CREATE TABLE IF NOT EXISTS tasks (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    list_id INTEGER,
                    parent_id INTEGER DEFAULT 0,
                    name TEXT,
                    notes TEXT DEFAULT '',
                    estimate INTEGER DEFAULT 0,
                    actual_time INTEGER DEFAULT 0,
                    position INTEGER DEFAULT 0,
                    scheduled_at INTEGER DEFAULT 0,
                    scheduled_time TEXT DEFAULT '',
                    recurrence_rule TEXT DEFAULT '',
                    is_completed INTEGER DEFAULT 0,
                    is_archived INTEGER DEFAULT 0,
                    created_at INTEGER,
                    FOREIGN KEY(list_id) REFERENCES lists(id)
                )`);

                // Subtasks: added position for reordering
                tx.executeSql("CREATE TABLE IF NOT EXISTS subtasks (id INTEGER PRIMARY KEY AUTOINCREMENT, task_id INTEGER, name TEXT, is_completed INTEGER DEFAULT 0, position INTEGER DEFAULT 0, FOREIGN KEY(task_id) REFERENCES tasks(id))");

                // Sessions: for historical reports
                tx.executeSql("CREATE TABLE IF NOT EXISTS sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, task_id INTEGER, started_at INTEGER, ended_at INTEGER, mode TEXT, duration INTEGER, FOREIGN KEY(task_id) REFERENCES tasks(id))");
                
                // Migration: Ensure 'notes' exists in older DBs
                try { tx.executeSql("ALTER TABLE tasks ADD COLUMN notes TEXT DEFAULT ''"); } catch(e) {}
                try { tx.executeSql("ALTER TABLE tasks ADD COLUMN recurrence_rule TEXT DEFAULT ''"); } catch(e) {}
                try { tx.executeSql("ALTER TABLE subtasks ADD COLUMN position INTEGER DEFAULT 0"); } catch(e) {}
            });
        } catch (e) {
            console.error("TaskDB: Failed to open database — " + e);
        }
        return db;
    }

    function run(callback, readOnly = false) {
        let database = openDB();
        if (!database) return;
        if (readOnly) database.readTransaction(callback);
        else database.transaction(callback);
    }

    // ── Helper: Natural Language Time Parser ─────────────────────
    /** 
     * Parses "Task Name 1h 30m" -> { name: "Task Name", seconds: 5400 }
     */
    function parseNaturalTime(input) {
        if (!input) return { name: "", seconds: 0 };
        
        let regex = /(\d+)\s*(hr|hrs|h|hour|hours|min|mins|m|minute|minutes)/gi;
        let totalSeconds = 0;
        let match;
        let strippedName = input;

        while ((match = regex.exec(input)) !== null) {
            let val = parseInt(match[1]);
            let unit = match[2].toLowerCase();
            
            if (unit.startsWith("h")) totalSeconds += val * 3600;
            else if (unit.startsWith("m")) totalSeconds += val * 60;
            
            strippedName = strippedName.replace(match[0], "");
        }

        return { 
            name: strippedName.trim().replace(/\s+/g, ' '), 
            seconds: totalSeconds 
        };
    }

    // ── Core API ──────────────────────────────────────────────────
    
    function getLists() {
        let r = [];
        run(tx => {
            let rs = tx.executeSql("SELECT * FROM lists ORDER BY id ASC");
            for (let i = 0; i < rs.rows.length; i++) r.push(rs.rows.item(i));
        }, true);
        return r;
    }

    function getTasks(listId, includeCompleted = false) {
        let r = [];
        let query = "SELECT * FROM tasks WHERE is_archived = 0";
        let params = [];
        
        if (listId > 0) {
            query += " AND list_id = ?";
            params.push(listId);
        }
        
        if (!includeCompleted) {
            query += " AND is_completed = 0";
        }
        
        query += " ORDER BY position ASC";
        
        run(tx => {
            let rs = tx.executeSql(query, params);
            for (let i = 0; i < rs.rows.length; i++) r.push(rs.rows.item(i));
        }, true);
        return r;
    }

    function getSubtasks(taskId) {
        let r = [];
        run(tx => {
            let rs = tx.executeSql("SELECT * FROM subtasks WHERE task_id = ? ORDER BY position ASC", [taskId]);
            for (let i = 0; i < rs.rows.length; i++) r.push(rs.rows.item(i));
        }, true);
        return r;
    }

    function createTask(listId, rawName, estimateOverride = -1, pos = 0) {
        let parsed = parseNaturalTime(rawName);
        let finalName = parsed.name || "Untitled Task";
        let finalEst = (estimateOverride >= 0) ? estimateOverride : parsed.seconds;
        let r;
        
        run(tx => {
            tx.executeSql(`INSERT INTO tasks 
                (list_id, name, estimate, position, created_at) 
                VALUES (?, ?, ?, ?, ?)`, 
                [listId, finalName, finalEst, pos, Math.floor(Date.now()/1000)]);
            r = tx.executeSql("SELECT * FROM tasks WHERE id = last_insert_rowid()").rows.item(0);
        });
        return r;
    }

    function updateTaskField(id, field, value) {
        const allowed = ["name", "notes", "estimate", "actual_time", "scheduled_at", "scheduled_time", "recurrence_rule", "position", "is_completed", "is_archived", "list_id"];
        if (allowed.indexOf(field) < 0) return;
        run(tx => {
            tx.executeSql(`UPDATE tasks SET ${field} = ? WHERE id = ?`, [value, id]);
        });
    }

    function toggleTaskCompletion(id) {
        run(tx => {
            let task = tx.executeSql("SELECT is_completed FROM tasks WHERE id = ?", [id]).rows.item(0);
            let newState = task.is_completed ? 0 : 1;
            tx.executeSql("UPDATE tasks SET is_completed = ? WHERE id = ?", [newState, id]);
            // If completed, move to end of position or something? 
            // The classification engine handles the 'Done' zone.
        });
    }

    function updateSubtask(id, field, value) {
        run(tx => {
            tx.executeSql(`UPDATE subtasks SET ${field} = ? WHERE id = ?`, [value, id]);
        });
    }

    function createSubtask(taskId, name) {
        run(tx => {
            let p = tx.executeSql("SELECT COUNT(*) as c FROM subtasks WHERE task_id = ?", [taskId]).rows.item(0).c;
            tx.executeSql("INSERT INTO subtasks (task_id, name, position) VALUES (?, ?, ?)", [taskId, name, p]);
        });
    }

    function deleteSubtask(id) {
        run(tx => tx.executeSql("DELETE FROM subtasks WHERE id = ?", [id]));
    }

    function createList(name, color, icon) {
        let r;
        run(tx => {
            tx.executeSql("INSERT INTO lists (name, color, icon) VALUES (?, ?, ?)", [name, color, icon]);
            r = tx.executeSql("SELECT * FROM lists WHERE id = last_insert_rowid()").rows.item(0);
        });
        return r;
    }
}
