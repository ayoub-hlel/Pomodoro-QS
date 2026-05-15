import QtQuick
import QtQuick.Layouts
import qs.services

/**
 * DragProxy — A visual "ghost" of a task card.
 */
Rectangle {
    id: root
    property string title: ""
    
    width: 300; height: 60
    color: Colours.tPalette.m3surfaceContainerHigh
    radius: 12; opacity: 0.8
    border.width: 2; border.color: Colours.palette.m3primary
    
    // Positioned by the mouse logic in shell
    z: 9999

    RowLayout {
        anchors.fill: parent; anchors.margins: 12
        spacing: 8
        Text {
            text: "\ue945"; font.family: "Material Symbols Rounded"
            color: Colours.palette.m3primary
        }
        Text {
            text: root.title
            font.pixelSize: 14; font.family: "Rubik"
            color: Colours.palette.m3onSurface
            Layout.fillWidth: true; elide: Text.ElideRight
        }
    }
}
