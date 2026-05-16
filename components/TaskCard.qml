import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
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
    readonly property int _subCount: (subtasks && subtasks.count) ? subtasks.count : 0
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
    implicitHeight: mainCol.implicitHeight + 16

    // ── Interaction Logic ────────────────────────────────────────
    states: [
        State {
            name: "hovered"
            when: hover.hovered && !root.isDragging
            PropertyChanges { target: bg; color: Colours.tPalette.m3surfaceContainerHigh }
            PropertyChanges { target: hoverControls; opacity: 1.0 }
        },
        State {
            name: "active"
            when: root.isActive && !root.isDragging
            PropertyChanges { target: bg; border.color: Colours.palette.m3primary; border.width: 2 }
        }
    ]

    transitions: [
        Transition {
            from: "*"; to: "*"
            ColorAnimation { duration: 150 }
            NumberAnimation { target: hoverControls; property: "opacity"; duration: 150 }
        }
    ]

    // ── Logic: Locked State ──────────────────────────────────────
    readonly property bool _isLive: TimerService.activeTaskId === _taskId && TimerService.state !== "idle"
    readonly property bool _canEditTitle: !_isLive
    readonly property bool _canEditFields: TimerService.state === "paused" || TimerService.state === "idle"

    // ── Background ──────────────────────────────────────────────
    Rectangle {
        id: bg
        anchors.fill: parent; radius: 8
        color: Colours.tPalette.m3surfaceContainerLow
        border.width: root.isActive ? 2 : 1
        border.color: root.isActive ? "transparent" : Qt.alpha(Colours.palette.m3outline, 0.1)

        // Shimmering border for active task
        Rectangle {
            anchors.fill: parent; radius: 8; z: -1; visible: root.isActive
            gradient: Gradient {
                id: shimmerGradient; orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Colours.palette.m3primary }
                GradientStop { id: shimmerStop; position: 0.5; color: Colours.palette.m3tertiary }
                GradientStop { position: 1.0; color: Colours.palette.m3primary }
            }
            SequentialAnimation on opacity {
                running: root.isActive; loops: Animation.Infinite
                NumberAnimation { from: 0.6; to: 1.0; duration: 1500; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1.0; to: 0.6; duration: 1500; easing.type: Easing.InOutQuad }
            }
        }
    }

    transform: Rotation {
        origin.x: width/2; origin.y: height/2
        angle: root.isDragging ? 4 : 0
        Behavior on angle { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
    }

    HoverHandler { id: hover; target: root }

    ColumnLayout {
        id: mainCol
        anchors { fill: parent; margins: 10 }
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // ── Drag Handle ────────────────────────────────────────
            Text {
                id: handle
                text: "\ue945" // drag_indicator
                font.family: "Material Symbols Rounded"; font.pixelSize: 18
                color: Colours.palette.m3onSurfaceVariant; opacity: hover.hovered ? 0.4 : 0.15
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

            // ── Title ──────────────────────────────────────────────
            TextInput {
                id: titleInput
                Layout.fillWidth: true
                text: _t.name || ""
                font.pixelSize: 13; font.weight: Font.Medium
                color: _done ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                opacity: _done ? 0.5 : 1.0
                readOnly: !_canEditTitle
                wrapMode: TextInput.Wrap; clip: true
                
                onAccepted: {
                    focus = false;
                    root.editTitle(_taskId, text);
                }
            }
            
            Drag.active: dragArea.pressed
            Drag.keys: ["task"]
            Drag.mimeData: { "taskId": _taskId.toString() }
            Drag.dragType: Drag.Internal

            // ── Hover Controls ─────────────────────────────────────
            RowLayout {
                id: hoverControls
                spacing: 2; opacity: 0
                
                IconBtn { 
                    icon: "\ue5c4"; size: 24; 
                    onClicked: root.moveColumn(_taskId, "left") 
                }
                
                Rectangle {
                    width: 18; height: 18; radius: 9
                    border.width: _done ? 0 : 1.5
                    border.color: Colours.palette.m3primary
                    color: _done ? Colours.palette.m3primary : "transparent"
                    Text { 
                        anchors.centerIn: parent; text: "\u2713"; 
                        color: "white"; font.pixelSize: 10
                        visible: _done 
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.taskToggled(_taskId) }
                }

                IconBtn { 
                    icon: "\ue5c8"; size: 24; 
                    onClicked: root.moveColumn(_taskId, "right") 
                }

                IconBtn { 
                    icon: "\ue5d3"; size: 24; 
                    onClicked: function(me) { root.menuRequested(_taskId, Qt.point(me.x, me.y)); }
                }
            }
        }

        // ── Info Row ───────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            visible: !_done || _actual > 0

            // Time Info
            RowLayout {
                spacing: 4
                Text {
                    text: Format.timer(_actual).substring(0, 5)
                    font.pixelSize: 10; font.family: "Monospace"
                    color: _isLive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    font.bold: _isLive
                }
                Text {
                    text: "/"
                    font.pixelSize: 10; color: Colours.palette.m3outline
                    visible: _est > 0
                }
                Text {
                    text: Format.timer(_est).substring(0, 5)
                    font.pixelSize: 10; font.family: "Monospace"
                    color: Colours.palette.m3onSurfaceVariant
                    visible: _est > 0
                }
            }

            Item { Layout.fillWidth: true }

            // Subtask Progress
            RowLayout {
                spacing: 4; visible: _subCount > 0
                Text {
                    text: _subDone + "/" + _subCount
                    font.pixelSize: 9; color: Colours.palette.m3onSurfaceVariant
                }
                Canvas {
                    width: 10; height: 10
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0,0,10,10);
                        ctx.beginPath();
                        ctx.arc(5,5,4, 0, 2*Math.PI);
                        ctx.strokeStyle = Qt.alpha(Colours.palette.m3outline, 0.2);
                        ctx.lineWidth = 1.5;
                        ctx.stroke();

                        if (_subFrac > 0) {
                            ctx.beginPath();
                            ctx.arc(5,5,4, -Math.PI/2, -Math.PI/2 + 2*Math.PI*_subFrac);
                            ctx.strokeStyle = Colours.palette.m3primary;
                            ctx.lineWidth = 1.5;
                            ctx.stroke();
                        }
                    }
                    Connections { target: root; function on_SubFracChanged() { parent.requestPaint(); } }
                }
            }

            // Scheduled Badge
            Rectangle {
                visible: _t.scheduled_time && _t.scheduled_time !== "00:00" && _t.scheduled_time !== ""
                color: Qt.alpha(Colours.palette.m3tertiary, 0.1)
                radius: 4; width: 40; height: 16
                Text {
                    anchors.centerIn: parent
                    text: _t.scheduled_time || ""
                    font.pixelSize: 9; font.bold: true
                    color: Colours.palette.m3tertiary
                }
            }
        }
    }
}
