import QtQuick
import QtQuick.Layouts
import qs.services

/**
 * TaskCard — Reusable card component for displaying a Pomodoro task.
 *
 * Visual Molecule: GlassCard + PremiumText (inline, no external component deps)
 * AXIOM_COLOR:  All colors from Colours.palette / Colours.tPalette — zero hex values.
 * AXIOM_ANIM:   Every visual state change has a Behavior with ColorAnimation/NumberAnimation.
 * AXIOM_TIME:   All durations in integer seconds.
 * AXIOM_DB:     No direct DB access — all data passed via properties.
 *
 * States (declarative):
 *   - normal      Default appearance
 *   - completed   Dimmed, filled checkbox
 *   - active      Highlighted with primary container (currently focused)
 *   - overdue     Error-tinted border when past scheduled time
 *   - dimmed      Snoozed task — reduced prominence
 */
Item {
    id: root

    // ── Public Properties ──────────────────────────────────────────
    /** Task data object — shape matches TaskDB's tasks table row */
    property var task: ({})

    /** Array of subtask objects for this task */
    property var subtasks: []

    /** Whether this task is currently in focus mode */
    property bool isActive: false

    /** Compact rendering mode (shorter card, less detail) */
    property bool compact: false

    /** Show estimate vs actual time on the card */
    property bool showEstimate: true

    // ── Signals ────────────────────────────────────────────────────
    /** Emitted when the user clicks the completion checkbox */
    signal toggleComplete(int taskId)

    /** Emitted when the user clicks the play/stop focus button */
    signal startFocus(int taskId)

    /** Emitted when the user requests deletion via the more menu */
    signal deleteRequested(int taskId)

    /** Emitted when the user wants to edit the task */
    signal editRequested(int taskId)

    // ── Derived State ──────────────────────────────────────────────
    readonly property bool _hasNotes: task.notes !== undefined && task.notes !== null && String(task.notes).length > 0
    readonly property bool _hasUrl: task.url !== undefined && task.url !== null && String(task.url).length > 0
    readonly property int _doneSubtaskCount: {
        if (!subtasks || subtasks.length === 0) return 0
        var count = 0
        for (var i = 0; i < subtasks.length; i++) {
            if (subtasks[i].is_completed) count++
        }
        return count
    }
    readonly property bool _isSnoozed: task.snoozed_until !== undefined && task.snoozed_until > 0 && task.snoozed_until > Math.floor(Date.now() / 1000)
    readonly property bool _isScheduled: task.scheduled_at !== undefined && task.scheduled_at > 0
    readonly property bool _isOverdue: _isScheduled && task.scheduled_at < Math.floor(Date.now() / 1000) && !task.is_completed

    // ── Dimensions ─────────────────────────────────────────────────
    implicitHeight: compact
        ? 56
        : contentColumn.implicitHeight + 24 + (subtasks.length > 0 ? 8 : 0)

    // ── States (declarative — no imperative visible/hacks) ─────────
    states: [
        State {
            name: "completed"
            when: task.is_completed === 1 || task.is_completed === true
            PropertyChanges { target: cardBg; color: Colours.tPalette.m3surfaceContainerHigh }
            PropertyChanges { target: cardBorder; color: Qt.alpha(Colours.palette.m3outlineVariant, 0.15) }
            PropertyChanges { target: taskName; opacity: 0.55 }
            PropertyChanges { target: taskName; color: Colours.palette.m3onSurfaceVariant }
            PropertyChanges { target: checkboxFill; color: Colours.palette.m3primary }
            PropertyChanges { target: checkboxFill; border.width: 0 }
            PropertyChanges { target: checkIcon; visible: true }
        },
        State {
            name: "active"
            when: root.isActive
            PropertyChanges { target: cardBg; color: Colours.tPalette.m3primaryContainer }
            PropertyChanges { target: cardBorder; color: Qt.alpha(Colours.palette.m3primary, 0.35) }
            PropertyChanges { target: cardBorder; border.width: 2 }
            PropertyChanges { target: taskName; color: Colours.palette.m3onPrimaryContainer }
            PropertyChanges { target: focusBtnBg; color: Colours.palette.m3primary }
            PropertyChanges { target: focusBtnIcon; color: Colours.palette.m3onPrimary }
        },
        State {
            name: "overdue"
            when: _isOverdue
            PropertyChanges { target: cardBorder; color: Qt.alpha(Colours.palette.m3error, 0.25) }
        },
        State {
            name: "dimmed"
            when: _isSnoozed && !task.is_completed && !root.isActive
            PropertyChanges { target: taskName; opacity: 0.4 }
            PropertyChanges { target: metaRow; opacity: 0.4 }
        }
    ]

    // ── Background (GlassCard equivalent) ──────────────────────────
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: 12
        color: Colours.tPalette.m3surfaceContainerLow

        Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }

        Rectangle {
            id: cardBorder
            anchors.fill: parent
            anchors.margins: -1
            radius: 13
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.2)

            Behavior on border.color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on border.width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }

    // ── Main Content ───────────────────────────────────────────────
    RowLayout {
        id: contentRow
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 12

        // ── 1. Completion Checkbox ─────────────────────────────────
        Item {
            id: checkboxArea
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignTop

            Rectangle {
                id: checkboxFill
                anchors.fill: parent
                radius: 12
                color: "transparent"
                border.width: 2
                border.color: Colours.palette.m3outline

                Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on border.width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Text {
                    id: checkIcon
                    anchors.centerIn: parent
                    text: "\u2713"  // checkmark unicode
                    color: Colours.palette.m3onPrimary
                    font.pixelSize: 14
                    visible: false
                }
            }

            MouseArea {
                id: checkboxClickArea
                anchors.fill: parent
                anchors.margins: -4 // Enlarged hit target
                cursorShape: Qt.PointingHandCursor
                propagateComposedEvents: false
                onClicked: root.toggleComplete(task.id !== undefined ? task.id : 0)
            }
        }

        // ── 2. Task Info Column ───────────────────────────────────
        ColumnLayout {
            id: contentColumn
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: compact ? 2 : 4

            // Task Name (PremiumText equivalent)
            Text {
                id: taskName
                Layout.fillWidth: true
                text: root.task.name || ""
                font.pixelSize: root.compact ? 13 : 15
                font.family: "Rubik"
                color: Colours.palette.m3onSurface
                opacity: 1.0
                elide: Text.ElideRight
                maximumLineCount: root.compact ? 1 : 2
                wrapMode: Text.Wrap

                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }

            // Secondary Info Row
            RowLayout {
                id: metaRow
                spacing: 8
                visible: !root.compact

                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                // Estimate / Actual
                Text {
                    id: estimateLabel
                    visible: root.showEstimate && ((task.estimate !== undefined && task.estimate > 0) || (task.actual_time !== undefined && task.actual_time > 0))
                    text: {
                        var parts = []
                        if (task.estimate > 0) parts.push(formatTime(task.estimate) + " est")
                        if (task.actual_time > 0) parts.push(formatTime(task.actual_time) + " actual")
                        return parts.join(" \u00b7 ")
                    }
                    font.pixelSize: 12
                    font.family: "CaskaydiaCove NF"
                    color: Colours.palette.m3onSurfaceVariant
                }

                // Subtask progress
                Text {
                    id: subtaskLabel
                    visible: root.subtasks !== undefined && root.subtasks.length > 0
                    text: root._doneSubtaskCount + "/" + root.subtasks.length + " subtasks"
                    font.pixelSize: 12
                    color: Colours.palette.m3onSurfaceVariant
                }

                // Schedule indicator
                Text {
                    id: scheduleLabel
                    visible: root._isScheduled
                    text: root._isOverdue ? "Overdue" : "Scheduled"
                    font.pixelSize: 12
                    font.family: "Rubik"
                    color: root._isOverdue ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                }

                // URL indicator icon (Material Symbols)
                Text {
                    id: urlIcon
                    visible: root._hasUrl
                    text: "\ue157"  // link icon
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 14
                    color: Colours.palette.m3primary
                }

                // Notes indicator icon (Material Symbols)
                Text {
                    id: notesIcon
                    visible: root._hasNotes
                    text: "\ue0b2"  // notes icon
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 14
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        // ── 3. Action Buttons Column ──────────────────────────────
        ColumnLayout {
            id: actionColumn
            spacing: 4
            Layout.alignment: Qt.AlignTop

            // Focus / Stop button
            Item {
                id: focusBtnArea
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                visible: !(task.is_completed === 1 || task.is_completed === true)

                Rectangle {
                    id: focusBtnBg
                    anchors.fill: parent
                    radius: 16
                    color: root.isActive ? Colours.palette.m3primary : Colours.palette.m3primaryContainer

                    Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }

                    Text {
                        id: focusBtnIcon
                        anchors.centerIn: parent
                        text: root.isActive ? "\ue047" : "\ue037"  // stop / play_arrow
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
                        color: root.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onPrimaryContainer
                    }
                }

                MouseArea {
                    id: focusClickArea
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startFocus(task.id !== undefined ? task.id : 0)
                }
            }

            // More / Delete button
            Text {
                id: moreBtn
                text: "\ue5d3"  // more_vert
                font.family: "Material Symbols Rounded"
                font.pixelSize: 18
                color: Colours.palette.m3onSurfaceVariant

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.deleteRequested(task.id !== undefined ? task.id : 0)
                }
            }
        }
    }

    // ── Subtask Progress Bar ───────────────────────────────────────
    Rectangle {
        id: progressBarBg
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 3
        radius: 1.5
        visible: root.subtasks !== undefined && root.subtasks.length > 0 && !root.compact
        color: Colours.tPalette.m3surfaceContainerHigh

        Rectangle {
            id: progressBarFill
            height: parent.height
            radius: 1.5
            color: (task.is_completed === 1 || task.is_completed === true)
                ? Colours.palette.m3success
                : Colours.palette.m3primary

            readonly property real _ratio: {
                var total = root.subtasks.length
                if (total === 0) return 0
                return root._doneSubtaskCount / total
            }

            readonly property real _animTarget: _ratio * progressBarBg.width
            property real animWidth: _animTarget

            onAnimWidthChanged: {
                if (width !== animWidth) {
                    animateWidth.to = animWidth
                    animateWidth.start()
                }
            }

            NumberAnimation {
                id: animateWidth
                target: progressBarFill
                property: "width"
                duration: 300
                easing.type: Easing.OutCubic
            }

            Component.onCompleted: width = _animTarget
        }
    }

    // ── Formatting Helpers ─────────────────────────────────────────
    function formatTime(seconds) {
        if (seconds === undefined || seconds === null || seconds < 0) return "0m"
        var s = Math.floor(seconds)
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }
}
