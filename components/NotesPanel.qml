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
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            // Toolbar (Placeholders for Rich Text Actions)
            IconBtn { icon: "\ue238"; size: 24; onClicked: console.log("Bold") }
            IconBtn { icon: "\ue23f"; size: 24; onClicked: console.log("Italic") }
            IconBtn { icon: "\ue241"; size: 24; onClicked: console.log("List") }
            
            Item { Layout.fillWidth: true }
            
            // Voice Mic
            IconBtn { icon: "\ue029"; size: 28; color: Colours.palette.m3primary; onClicked: console.log("Transcribe") }
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
