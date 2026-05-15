import QtQuick
import QtQuick.Layouts
import qs.services

/**
 * TaskCard — Reusable card component for displaying a Pomodoro task.
 * Hardened: Support both Array and ListModel for subtasks to prevent render failure.
 */
Item {
    id: root

    // ── Public Properties ──────────────────────────────────────────
    property var task: ({})
    property var subtasks: [] // Can be Array or ListModel
    property bool isActive: false
    property bool compact: false
    property bool showEstimate: true

    // ── Signals ────────────────────────────────────────────────────
    signal toggleComplete(int taskId)
    signal startFocus(int taskId)
    signal deleteRequested(int taskId)
    signal editRequested(int taskId)
    signal subtaskToggled(int taskId, int subtaskId, bool isCompleted)

    // ── Derived State (Type-Agnostic) ──────────────────────────────
    readonly property var _t: task || {}
    
    // Abstract the count and item access to handle ListModel vs Array
    readonly property int _subtaskCount: {
        if (!subtasks) return 0
        return subtasks.count !== undefined ? subtasks.count : (subtasks.length !== undefined ? subtasks.length : 0)
    }

    readonly property int _doneSubtaskCount: {
        var count = 0
        var len = _subtaskCount
        for (var i = 0; i < len; i++) {
            var item = subtasks.get !== undefined ? subtasks.get(i) : subtasks[i]
            if (item && (item.is_completed === 1 || item.is_completed === true)) count++
        }
        return count
    }

    readonly property bool _isSnoozed: _t.snoozed_until !== undefined && _t.snoozed_until > 0 && _t.snoozed_until > Math.floor(Date.now() / 1000)
    readonly property bool _isScheduled: _t.scheduled_at !== undefined && _t.scheduled_at > 0
    readonly property bool _isOverdue: _isScheduled && _t.scheduled_at < Math.floor(Date.now() / 1000) && !(_t.is_completed === 1 || _t.is_completed === true)

    implicitHeight: compact ? 56 : mainLayout.implicitHeight + 24
    Behavior on implicitHeight { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    // ── Background ──────────────────────────────────────────────────
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: 12
        color: Colours.tPalette.m3surfaceContainerLow
        
        Rectangle {
            id: cardBorder
            anchors.fill: parent
            anchors.margins: -1
            radius: 13
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.2)
        }
        Behavior on color { ColorAnimation { duration: 300 } }
    }

    ColumnLayout {
        id: mainLayout
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 12; leftMargin: 12; rightMargin: 12 }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item {
                Layout.preferredWidth: 24; Layout.preferredHeight: 24; Layout.alignment: Qt.AlignTop
                Rectangle {
                    anchors.fill: parent; radius: 12
                    color: (_t.is_completed === 1 || _t.is_completed === true) ? Colours.palette.m3primary : "transparent"
                    border.width: (_t.is_completed === 1 || _t.is_completed === true) ? 0 : 2
                    border.color: Colours.palette.m3outline
                    Text { anchors.centerIn: parent; text: "\u2713"; color: Colours.palette.m3onPrimary; font.pixelSize: 14; visible: _t.is_completed === 1 || _t.is_completed === true }
                }
                MouseArea { anchors.fill: parent; onClicked: root.toggleComplete(_t.id || 0) }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text {
                    Layout.fillWidth: true; text: _t.name || ""
                    font.pixelSize: 15; font.family: "Rubik"
                    color: (_t.is_completed === 1 || _t.is_completed === true) ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                    opacity: (_t.is_completed === 1 || _t.is_completed === true) ? 0.55 : 1.0
                    elide: Text.ElideRight; maximumLineCount: root.compact ? 1 : 2; wrapMode: Text.Wrap
                }
                RowLayout {
                    spacing: 8; visible: !root.compact
                    Text {
                        visible: root.showEstimate && ((_t.estimate || 0) > 0 || (_t.actual_time || 0) > 0)
                        text: { var p = []; if (_t.estimate > 0) p.push(formatTime(_t.estimate) + " est"); if (_t.actual_time > 0) p.push(formatTime(_t.actual_time) + " actual"); return p.join(" \u00b7 "); }
                        font.pixelSize: 12; font.family: "CaskaydiaCove NF"; color: Colours.palette.m3onSurfaceVariant
                    }
                    Text {
                        visible: _subtaskCount > 0
                        text: root._doneSubtaskCount + "/" + _subtaskCount + " subtasks"
                        font.pixelSize: 12; color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            Item {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32
                visible: !(_t.is_completed === 1 || _t.is_completed === true)
                Rectangle {
                    anchors.fill: parent; radius: 16
                    color: root.isActive ? Colours.palette.m3primary : Colours.palette.m3primaryContainer
                    Text { anchors.centerIn: parent; text: root.isActive ? "\ue047" : "\ue037"; font.family: "Material Symbols Rounded"; font.pixelSize: 18; color: root.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onPrimaryContainer }
                }
                MouseArea { anchors.fill: parent; onClicked: root.startFocus(_t.id || 0) }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true; Layout.leftMargin: 36
            spacing: 2; visible: _subtaskCount > 0 && !root.compact
            Repeater {
                model: root.subtasks
                delegate: SubtaskRow {
                    Layout.fillWidth: true
                    // modelData is used for Arrays, model is used for ListModels
                    subtask: modelData !== undefined ? modelData : model
                    onToggled: root.subtaskToggled(_t.id || 0, subtaskId, isCompleted)
                }
            }
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 3; radius: 1.5; visible: _subtaskCount > 0 && !root.compact
        color: Colours.tPalette.m3surfaceContainerHigh
        Rectangle {
            width: (_subtaskCount > 0 ? (root._doneSubtaskCount / _subtaskCount) : 0) * parent.width
            height: parent.height; radius: 1.5
            color: (_t.is_completed === 1 || _t.is_completed === true) ? Colours.palette.m3success : Colours.palette.m3primary
            Behavior on width { NumberAnimation { duration: 300 } }
        }
    }

    function formatTime(s) { if (!s) return "0m"; var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60); return (h > 0 ? h + "h " : "") + m + "m"; }
}
