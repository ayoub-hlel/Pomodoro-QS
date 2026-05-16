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

            Flow {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: 7
                    delegate: Button {
                        property int dayStart: TestData._todayStart() + index * 86400
                        text: {
                            let d = new Date(dayStart * 1000);
                            return d.toLocaleDateString(undefined, { weekday: 'short', day: 'numeric' });
                        }
                        onClicked: { root.selectedDate = dayStart; stack.currentIndex = 1; }
                    }
                }
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
                Text { text: "Time"; color: Colours.palette.m3onSurfaceVariant }
                TextField {
                    id: timeInput
                    placeholderText: "09:00"
                    inputMask: "99:99"
                    font.family: "Monospace"
                    Layout.preferredWidth: 70
                    text: "09:00"
                }
            }

            Flow {
                Layout.fillWidth: true; spacing: 8
                Button { text: "09:00"; onClicked: timeInput.text = "09:00" }
                Button { text: "13:00"; onClicked: timeInput.text = "13:00" }
                Button { text: "17:00"; onClicked: timeInput.text = "17:00" }
                Button { text: "21:00"; onClicked: timeInput.text = "21:00" }
            }

            ColumnLayout {
                spacing: 4
                Text { text: "Repeat"; font.bold: true; color: Colours.palette.m3onSurfaceVariant }
                ComboBox {
                    id: repeatCombo
                    Layout.fillWidth: true
                    model: ["No Repeat", "Every day", "Every weekday", "Weekly", "Monthly"]
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
                        TaskDB.updateTaskField(root.taskId, "recurrence_rule", repeatCombo.currentText === "No Repeat" ? "" : repeatCombo.currentText);
                        TestData.syncTask(root.taskId);
                        root.close();
                    }
                }
            }
        }
    }
}
