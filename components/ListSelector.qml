import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services

Item {
    id: root
    implicitWidth: 200; implicitHeight: 40

    Rectangle {
        anchors.fill: parent; radius: 8
        color: Colours.tPalette.m3surfaceContainerHigh
        
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 8
            
            Rectangle {
                width: 12; height: 12; radius: 6
                color: TestData.list ? TestData.list.color : Colours.palette.m3primary
            }
            
            Text {
                text: TestData.list ? TestData.list.name : "Select List"
                font.pixelSize: 14; font.family: "Rubik"; font.bold: true
                color: Colours.palette.m3onSurface
                Layout.fillWidth: true
            }

            Text {
                text: "\ue5c5" // arrow_drop_down
                font.family: "Material Symbols Rounded"; font.pixelSize: 20
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: listMenu.open()
        }
    }

    Menu {
        id: listMenu
        y: parent.height + 4
        
        MenuItem {
            text: "All Lists View"
            onTriggered: {
                TestData.activeListId = 0;
                TestData.loadFromDB();
            }
        }

        MenuSeparator {}

        Instantiator {
            model: TaskDB.getLists()
            onObjectAdded: (index, obj) => listMenu.insertItem(index + 2, obj)
            delegate: MenuItem {
                text: modelData.name
                onTriggered: {
                    TestData.activeListId = modelData.id;
                    TestData.loadFromDB();
                }
            }
        }
    }
}
