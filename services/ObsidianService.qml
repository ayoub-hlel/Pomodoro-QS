pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * ObsidianService — Bi-directional sync with Obsidian vault.
 */
Item {
    id: root

    property string vaultPath: "~/Documents/Obsidian/Vault" 
    property bool autoSync: true

    function syncTask(task) {
        if (!task || !task.name) return;
        
        let safeName = task.name.replace(/[\/\\?%*:|"<>]/g, '-');
        let content = `---\n`;
        content += `id: ${task.id}\n`;
        content += `estimate: ${task.estimate}\n`;
        content += `actual_time: ${task.actual_time}\n`;
        content += `scheduled: ${task.scheduled_at}\n`;
        content += `status: ${task.is_completed ? "completed" : "pending"}\n`;
        content += `---\n\n`;
        content += `# ${task.name}\n\n`;
        content += `## Notes\n${task.notes || ""}\n\n`;
        
        if (task.subtasksList && task.subtasksList.length > 0) {
            content += `## Subtasks\n`;
            for (let i = 0; i < task.subtasksList.length; i++) {
                let st = task.subtasksList[i];
                content += `- [${st.is_completed ? "x" : " "}] ${st.name}\n`;
            }
        }

        // Write to file via shell command
        let path = vaultPath + "/Pomodoro/Tasks/" + safeName + ".md";
        let cmd = "mkdir -p \"$(dirname \"" + path.replace("~", "$HOME") + "\")\" && echo \"" + content.replace(/"/g, '\\"').replace(/\n/g, '\\n') + "\" > \"" + path.replace("~", "$HOME") + "\"";
        
        Process.execDetached(["sh", "-c", cmd]);
    }
}
