import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services

Rectangle {
    id: root
    width: 300; height: 120; radius: 16
    color: Colours.palette.m3primaryContainer
    border.width: 1; border.color: Colours.palette.m3primary
    
    property var dueTasks: []
    signal doNow(int taskId)
    signal doLater(int taskId)

    visible: dueTasks.length > 0

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 16
        spacing: 8
        
        Text {
            text: "Tasks due now — You have " + dueTasks.length + " scheduled tasks."
            font.pixelSize: 12; font.bold: true; color: Colours.palette.m3onPrimaryContainer
            wrapMode: Text.Wrap; Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 8
            Button { text: "Do later"; onClicked: root.doLater(dueTasks[0].id) }
            Button { 
                text: "Do now"; highlighted: true
                onClicked: root.doNow(dueTasks[0].id)
            }
        }
    }
}
