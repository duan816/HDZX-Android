import QtQuick
import QtQuick.Shapes

// Original line drawing: satellite bus, two solar panels and a receive arc.
Item {
    id: root
    property color color: "#32D3B6"
    implicitWidth: 24
    implicitHeight: 24
    Item {
        width: 24; height: 24
        scale: Math.min(root.width, root.height) / 24
        anchors.centerIn: parent
        rotation: -32
        Rectangle { x: 9; y: 7; width: 6; height: 9; radius: 1; color: "transparent"; border.color: root.color; border.width: 1.5 }
        Rectangle { x: 1; y: 8; width: 6; height: 7; radius: 0.5; color: "transparent"; border.color: root.color; border.width: 1.3 }
        Rectangle { x: 17; y: 8; width: 6; height: 7; radius: 0.5; color: "transparent"; border.color: root.color; border.width: 1.3 }
        Rectangle { x: 7; y: 10.5; width: 2; height: 1.5; color: root.color }
        Rectangle { x: 15; y: 10.5; width: 2; height: 1.5; color: root.color }
        Rectangle { x: 11.3; y: 16; width: 1.4; height: 3; color: root.color }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.color; strokeWidth: 1.3; fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: root.width * 0.64; startY: root.height * 0.76
            PathQuad { x: root.width * 0.87; y: root.height * 0.53; controlX: root.width * 0.82; controlY: root.height * 0.77 }
        }
    }
}
