import QtQuick
import QtQuick.Layouts
import qs.services

/**
 * SubtaskRow — Single subtask checklist row for use inside TaskCard.
 *
 * AXIOM_COLOR:  All colors from Colours.palette / Colours.tPalette — zero hex values.
 * AXIOM_ANIM:   Every visual state change has a Behavior with animation.
 * AXIOM_DB:     No direct DB access — all data passed via properties.
 * AXIOM_TIME:   All durations in integer seconds.
 *
 * Visual molecule: Inline checkbox + label, matching TaskCard's checkbox style
 * at a smaller scale. States are driven entirely by the `subtask.is_completed`
 * property — no imperative visible/opacity hacks.
 */
Item {
    id: root

    // ── Public Properties ──────────────────────────────────────────
    /** Subtask data object — shape matches subtasks table row */
    property var subtask: ({})

    /** Whether the row is editable (show remove button, allow click) */
    property bool editable: true

    /** Whether to show a remove/delete button on hover */
    property bool showRemove: false

    /** Row height */
    readonly property int rowHeight: 28

    // ── Signals ────────────────────────────────────────────────────
    /** Emitted when user clicks the checkbox */
    signal toggled(int subtaskId, bool isCompleted)

    /** Emitted when user clicks the remove button */
    signal removeRequested(int subtaskId)

    // ── Derived State ──────────────────────────────────────────────
    readonly property bool _completed: subtask.is_completed === 1 || subtask.is_completed === true
    readonly property int _sId: subtask.id !== undefined ? subtask.id : 0

    // ── Layout height — explicit so ColumnLayout gets unambiguous sizing ─
    implicitHeight: rowHeight
    Layout.minimumHeight: rowHeight
    Layout.preferredHeight: rowHeight

    // ── Background (subtle hover highlight) ────────────────────────
    Rectangle {
        id: rowBg
        anchors.fill: parent
        radius: 6
        color: hoverArea.containsMouse || chkClick.containsMouse
            ? Qt.alpha(Colours.palette.m3onSurface, 0.04)
            : "transparent"

        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    // ── Full-row hover detection ──────────────────────────────────
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        enabled: root.editable
        onClicked: mouse.accepted = false
        onPressed: mouse.accepted = false
        onReleased: mouse.accepted = false
    }

    // ── Layout ─────────────────────────────────────────────────────
    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 4
        spacing: 8

        // ── Checkbox (mini version of TaskCard's) ──────────────────
        Item {
            id: chkArea
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: chkFill
                anchors.fill: parent
                radius: 9
                color: root._completed ? Colours.palette.m3primary : "transparent"
                border.width: root._completed ? 0 : 2
                border.color: root._completed
                    ? "transparent"
                    : Colours.palette.m3outline

                Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on border.width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Text {
                    id: chkIcon
                    anchors.centerIn: parent
                    text: "\u2713"
                    color: Colours.palette.m3onPrimary
                    font.pixelSize: 11
                    visible: root._completed
                }
            }

            MouseArea {
                id: chkClick
                anchors.fill: parent
                anchors.margins: -4  // bigger hit target
                cursorShape: Qt.PointingHandCursor
                enabled: root.editable
                hoverEnabled: true
                onClicked: root.toggled(root._sId, !root._completed)
            }
        }

        // ── Subtask Name ───────────────────────────────────────────
        Text {
            id: subtaskName
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: root.subtask.name || ""
            font.pixelSize: 13
            font.family: "Rubik"
            color: root._completed
                ? Colours.palette.m3onSurfaceVariant
                : Colours.palette.m3onSurface
            opacity: root._completed ? 0.55 : 1.0
            elide: Text.ElideRight
            maximumLineCount: 1

            Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }

        // ── Remove Button ──────────────────────────────────────────
        Item {
            id: removeArea
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
            visible: root.showRemove && root.editable

            Rectangle {
                id: removeBg
                anchors.fill: parent
                radius: 10
                color: removeMouse.containsMouse
                    ? Qt.alpha(Colours.palette.m3error, 0.12)
                    : "transparent"

                Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: "\ue5cd"  // close (Material Symbols)
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 14
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            MouseArea {
                id: removeMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.removeRequested(root._sId)
            }
        }
    }
}
