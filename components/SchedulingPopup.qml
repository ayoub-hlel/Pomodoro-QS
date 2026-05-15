import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import "."

Popup {
    id: root
    width: 320; height: 400
    modal: true; focus: true
    anchors.centerIn: parent

    property int taskId: 0
    property int selectedDate: 0
    
    background: Rectangle {
        color: Colours.tPalette.m3surfaceContainerLow
        radius: 16; border.width: 1; border.color: Qt.alpha(Colours.palette.m3outline, 0.2)
    }

    StackLayout {
        id: stack; anchors.fill: parent; anchors.margins: 16
        
        // Screen 1: Date Picker
        ColumnLayout {
            spacing: 12
            Text { text: "Schedule Task"; font.pixelSize: 18; font.bold: true; color: Colours.palette.m3onSurface }

            GridLayout {
                columns: 2; Layout.fillWidth: true
                Button { 
                    Layout.fillWidth: true; text: "Today"; 
                    onClicked: { root.selectedDate = TestData._todayStart(); stack.currentIndex = 1; }
                }
                Button { 
                    Layout.fillWidth: true; text: "Tomorrow"; 
                    onClicked: { root.selectedDate = TestData._todayStart() + 86400; stack.currentIndex = 1; }
                }
                Button { 
                    Layout.fillWidth: true; text: "Next Week"; 
                    onClicked: { root.selectedDate = TestData._todayStart() + 7*86400; stack.currentIndex = 1; }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
                Text { anchors.centerIn: parent; text: "[Full Calendar Placeholder]"; color: Colours.palette.m3outline }
            }

            Button { 
                text: "Next"; Layout.alignment: Qt.AlignRight
                onClicked: stack.currentIndex = 1
            }
        }

        // Screen 2: Time & Recurrence
        ColumnLayout {
            spacing: 12
            Text { text: "Time & Recurrence"; font.pixelSize: 18; font.bold: true; color: Colours.palette.m3onSurface }

            RowLayout {
                spacing: 8
                Text { text: "Time (HH:MM)"; color: Colours.palette.m3onSurfaceVariant }
                TextField {
                    id: timeInput
                    placeholderText: "09:00"
                    inputMask: "99:99"
                    font.family: "CaskaydiaCove NF"
                    Layout.preferredWidth: 80
                }
            }

            ColumnLayout {
                spacing: 4
                Text { text: "Repeat"; font.bold: true; color: Colours.palette.m3onSurfaceVariant }
                ComboBox {
                    Layout.fillWidth: true
                    model: ["No Repeat", "Every day", "Every weekday", "Weekly", "Monthly", "Custom"]
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                Button { text: "Back"; onClicked: stack.currentIndex = 0 }
                Item { Layout.fillWidth: true }
                Button { 
                    text: "Confirm Schedule"; 
                    highlighted: true
                    onClicked: {
                        TaskDB.updateTaskField(root.taskId, "scheduled_at", root.selectedDate);
                        TaskDB.updateTaskField(root.taskId, "scheduled_time", timeInput.text);
                        TestData.syncTask(root.taskId);
                        root.close();
                    }
                }
            }
        }
    }
}
