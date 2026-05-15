import QtQuick
import QtQuick.Layouts
import qs.services

/**
 * TimerControlButton — Icon + label button for TimerDisplay.
 *
 * AXIOM_COLOR: Button/tint colors passed as properties.
 * AXIOM_ANIM:  Background has Behavior color animation.
 */
Item {
    id: root

    // ── Properties ─────────────────────────────────────────────────
    property string icon: ""
    property string label: ""
    property color btnColor: Colours.palette.m3primary
    property color btnTextColor: Colours.palette.m3onPrimary
    property int btnRadius: 14

    // ── Signals ────────────────────────────────────────────────────
    signal clicked()

    implicitWidth: 72
    implicitHeight: 64

    // ── Background ─────────────────────────────────────────────────
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.btnRadius
        color: root.enabled && mouse.containsMouse
            ? Qt.lighter(root.btnColor, 1.12)
            : root.btnColor
        Behavior on color { ColorAnimation { duration: 200 } }

        // Icon + (optional label) centered
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.icon
                font.family: "Material Symbols Rounded"
                font.pixelSize: 26
                color: root.btnTextColor
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.label
                font.pixelSize: root.label.length > 0 ? 9 : 0
                font.letterSpacing: 0.5
                font.family: "Rubik"
                color: root.btnTextColor
                opacity: 0.75
            }
        }
    }

    // ── Click / Hover Area ─────────────────────────────────────────
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
