import QtQuick
import QtQuick.Layouts
import qs.services

/**
 * TaskCard — Blitzit-style Molecule.
 *
 * Layout: Drag Handle | [Title] | Hover Controls
 * Bottom: EST (HH:MM) | Progress Ring | Time Taken (HH:MM)
 */
Item {
    id: root

    // ── Properties ──────────────────────────────────────────────
    property var task: ({})
    property var subtasks: []
    property bool isActive: false
    
    readonly property var _t: task || {}
    readonly property int _taskId: _t.id || 0
    readonly property bool _done: _t.is_completed === 1
    readonly property int _est: _t.estimate || 0
    readonly property int _actual: _t.actual_time || 0
    
    // Subtask count helpers
    readonly property int _subCount: subtasks.count || 0
    readonly property int _subDone: {
        let c = 0;
        if (subtasks && subtasks.count) {
            for (let i = 0; i < subtasks.count; i++) {
                if (subtasks.get(i).is_completed) c++;
            }
        }
        return c;
    }
    readonly property real _subFrac: _subCount > 0 ? _subDone / _subCount : 0

    // Signals for the Shell to handle
    signal taskToggled(int taskId)
    signal moveColumn(int taskId, string direction)
    signal menuRequested(int taskId, point pos)
    signal editTitle(int taskId, string newName)
    signal dragStart(int taskId, string title, point pos)
    signal dragMove(point pos)
    signal dragEnd()
    
    property bool isDragging: false

    implicitWidth: 320
    implicitHeight: mainCol.implicitHeight + 24

    // ── Logic: Locked State ──────────────────────────────────────
    readonly property bool _isLive: TimerService.activeTaskId === _taskId && TimerService.state !== "idle"
    readonly property bool _canEditTitle: !_isLive
    readonly property bool _canEditFields: TimerService.state === "paused" || TimerService.state === "idle"

    // ── Background ──────────────────────────────────────────────
    Rectangle {
        id: bg
        anchors.fill: parent; radius: 12
        color: root.isActive ? Qt.alpha(Colours.palette.m3primary, 0.08) : Colours.tPalette.m3surfaceContainerLow
        border.width: 1
        border.color: root.isActive ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.2)
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    HoverHandler { id: hover; target: root }

    ColumnLayout {
        id: mainCol
        anchors { fill: parent; margins: 12 }
        spacing: 8
        opacity: root.isDragging ? 0.3 : 1.0

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // ── Drag Handle ────────────────────────────────────────
            Text {
                id: handle
                text: "\ue945" // drag_indicator
                font.family: "Material Symbols Rounded"; font.pixelSize: 20
                color: Colours.palette.m3onSurfaceVariant; opacity: 0.3
                Layout.alignment: Qt.AlignVCenter
                
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    onPressed: (mouse) => {
                        let global = root.mapToItem(root.Window.contentItem, mouse.x, mouse.y);
                        root.isDragging = true;
                        root.dragStart(_taskId, _t.name, global);
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) {
                            let global = root.mapToItem(root.Window.contentItem, mouse.x, mouse.y);
                            root.dragMove(global);
                        }
                    }
                    onReleased: {
                        root.isDragging = false;
                        root.dragEnd();
                    }
                }
            }
            
            Drag.active: dragArea.pressed
            Drag.keys: ["task"]
            Drag.mimeData: { "taskId": _taskId.toString() }
            Drag.dragType: Drag.Internal

            // ── Title ──────────────────────────────────────────────
            TextInput {
                id: titleInput
                Layout.fillWidth: true
                text: _t.name || ""
                font.pixelSize: 14; font.family: "Rubik"
                color: _done ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                opacity: _done ? 0.5 : 1.0
                readOnly: !_canEditTitle
                wrapMode: TextInput.Wrap; clip: true
                
                onAccepted: {
                    focus = false;
                    root.editTitle(_taskId, text);
                }
            }

            // ── Scheduled Time Badge ───────────────────────────────
            Rectangle {
                visible: _t.scheduled_time && _t.scheduled_time !== "00:00" && _t.scheduled_time !== ""
                Layout.alignment: Qt.AlignVCenter
                color: Qt.alpha(Colours.palette.m3tertiary, 0.12)
                radius: 4; width: 44; height: 18
                Text {
                    anchors.centerIn: parent
                    text: _t.scheduled_time || ""
                    font.pixelSize: 10; font.family: "CaskaydiaCove NF"; font.bold: true
                    color: Colours.palette.m3tertiary
                }
            }

            // ── Hover Controls ─────────────────────────────────────
            RowLayout {
                spacing: 4; visible: hover.hovered && !_done
                
                // Left Arrow
                IconBtn { 
                    icon: "\ue5c4"; size: 28; 
                    onClicked: root.moveColumn(_taskId, "left") 
                }
                
                // Checkbox
                Rectangle {
                    width: 22; height: 22; radius: 11
                    border.width: _done ? 0 : 2
                    border.color: Colours.palette.m3primary
                    color: _done ? Colours.palette.m3primary : "transparent"
                    Text { 
                        anchors.centerIn: parent; text: "\u2713"; 
                        color: "white"; font.pixelSize: 13
                        visible: _done 
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.toggleComplete(_taskId) }
                }

                // Right Arrow
                IconBtn { 
                    icon: "\ue5c8"; size: 28; 
                    onClicked: root.moveColumn(_taskId, "right") 
                }

                // Menu
                IconBtn { 
                    icon: "\ue5d3"; size: 28; 
                    onClicked: function(me) { root.menuRequested(_taskId, Qt.point(me.x, me.y)); }
                }
            }
        }

        // ── Bottom Row ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // EST (HH:MM)
            TextInput {
                text: Format.timer(_est).substring(0, 5) // HH:MM
                font.pixelSize: 11; font.family: "CaskaydiaCove NF"
                color: Colours.palette.m3onSurfaceVariant
                readOnly: !_canEditFields
                inputMask: "99:99"
                onAccepted: {
                    let parts = text.split(":");
                    let secs = parseInt(parts[0])*3600 + parseInt(parts[1])*60;
                    TaskDB.updateTaskField(_taskId, "estimate", secs);
                    TestData.syncTask(_taskId);
                }
            }

            Item { Layout.fillWidth: true }

            // Progress Ring
            Canvas {
                width: 16; height: 16
                visible: _subCount > 0
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0,0,16,16);
                    ctx.beginPath();
                    ctx.arc(8,8,6, 0, 2*Math.PI);
                    ctx.strokeStyle = Colours.tPalette.m3surfaceContainerHigh;
                    ctx.lineWidth = 2;
                    ctx.stroke();

                    if (_subFrac > 0) {
                        ctx.beginPath();
                        ctx.arc(8,8,6, -Math.PI/2, -Math.PI/2 + 2*Math.PI*_subFrac);
                        ctx.strokeStyle = Colours.palette.m3primary;
                        ctx.lineWidth = 2;
                        ctx.stroke();
                    }
                }
                Connections { target: root; function on_SubFracChanged() { parent.requestPaint(); } }
            }

            // Time Taken (HH:MM)
            Text {
                text: Format.timer(_actual).substring(0, 5)
                font.pixelSize: 11; font.family: "CaskaydiaCove NF"
                color: Colours.palette.m3primary
                opacity: 0.8
            }
        }
    }
}
