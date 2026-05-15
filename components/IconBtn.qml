import QtQuick
import qs.services

Item {
    id: root
    property string icon: ""
    property int size: 24
    property color color: Colours.palette.m3onSurfaceVariant
    
    signal clicked(var mouse)

    width: size; height: size

    Rectangle {
        anchors.fill: parent; radius: size/2
        color: mouse.containsMouse ? Qt.alpha(root.color, 0.1) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
        
        Text {
            anchors.centerIn: parent
            text: root.icon
            font.family: "Material Symbols Rounded"
            font.pixelSize: root.size * 0.7
            color: root.color
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: (me) => root.clicked(me)
    }
}
