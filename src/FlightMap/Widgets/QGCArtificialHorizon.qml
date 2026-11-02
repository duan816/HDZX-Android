import QtQuick

Item {
    id: root
    property real rollAngle :   0
    property real pitchAngle:   0
    property bool dayColors: false
    clip:           true
    anchors.fill:   parent

    property real angularScale: pitchAngle * root.height / 45

    Item {
        id: artificialHorizon
        width:  root.width  * 4
        height: root.height * 8
        anchors.centerIn: parent
        Rectangle {
            id: sky
            anchors.fill: parent
            smooth: true
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0.25; color: root.dayColors ? "#397FAE" : "#0A2B17" }
                GradientStop { position: 0.5;  color: root.dayColors ? "#79B2D4" : "#17472A" }
            }
        }
        Rectangle {
            id: ground
            height: sky.height / 2
            anchors {
                left:   sky.left;
                right:  sky.right;
                bottom: sky.bottom
            }
            smooth: true
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0.0;  color: root.dayColors ? "#647B45" : "#06140B" }
                GradientStop { position: 0.25; color: root.dayColors ? "#364C35" : "#020805" }
            }
        }
        Rectangle {
            anchors.left: ground.left
            anchors.right: ground.right
            anchors.top: ground.top
            height: 2
            color: root.dayColors ? "#E6F1F8" : "#7CFF8A"
        }
        transform: [
            Translate {
                y:  angularScale
            },
            Rotation {
                origin.x: artificialHorizon.width  / 2
                origin.y: artificialHorizon.height / 2
                angle:    -rollAngle
            }]
    }
}
