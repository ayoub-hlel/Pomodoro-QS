import QtQuick
import QtQuick.Layouts
import qs.services

/**
 * SectionHeader — Section header with icon, title, task count, and optional progress.
 *
 * Shows "5 tasks" or "3/5 done" depending on doneCount.
 *
 * AXIOM_COLOR: accentColor passed as property.
 */
Item {
    id: root

    property string title: ""
    property string icon: "\ue8df"
    property int count: 0
    property int doneCount: -1    // -1 = don't show, 0+ = show "X/Y done"
    property color accentColor: Colours.palette.m3primary

    readonly property bool _showProgress: root.doneCount >= 0 && root.count > 0

    implicitHeight: 42
    Layout.fillWidth: true

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Qt.alpha(root.accentColor, 0.06)

        RowLayout {
            anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
            spacing: 8

            Text {
                text: root.icon
                font.family: "Material Symbols Rounded"
                font.pixelSize: 18
                color: root.accentColor
            }

            Text {
                text: root.title
                font.pixelSize: 14; font.family: "Rubik"; font.bold: true
                color: root.accentColor
            }

            // Count or progress
            Text {
                text: root._showProgress
                    ? root.doneCount + "/" + root.count + " done"
                    : root.count + " tasks"
                font.pixelSize: 12; font.family: "CaskaydiaCove NF"
                color: Qt.alpha(root.accentColor, 0.6)
            }

            Item { Layout.fillWidth: true }

            // Progress dot (filled if all done)
            Rectangle {
                Layout.preferredWidth: 6; Layout.preferredHeight: 6; radius: 3
                color: root._showProgress && root.doneCount === root.count
                    ? Colours.palette.m3success
                    : root.accentColor
                opacity: 0.5
            }
        }
    }
}
