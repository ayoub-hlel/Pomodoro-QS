import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import "."

Rectangle {
    id: root
    property int taskId: 0
    property string initialNotes: ""

    color: Colours.tPalette.m3surfaceContainerHigh; radius: 12
    implicitHeight: 200

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 12
        spacing: 8
        
        Text { 
            text: "NOTES"; font.pixelSize: 10; font.weight: Font.Black; 
            color: Colours.palette.m3onSurfaceVariant; opacity: 0.6 
        }

        ScrollView {
            Layout.fillWidth: true; Layout.fillHeight: true
            TextArea {
                id: notesArea
                text: root.initialNotes
                placeholderText: "Add notes here..."
                textFormat: TextEdit.RichText
                font.pixelSize: 13; font.family: "Rubik"
                wrapMode: TextArea.Wrap
                color: Colours.palette.m3onSurface
                
                onTextChanged: {
                    if (focus) {
                        TaskDB.updateTaskField(root.taskId, "notes", text);
                    }
                }
            }
        }
    }
}
