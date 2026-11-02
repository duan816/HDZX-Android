import QGroundControl.Controls
import QGroundControl
import QtQuick
import QtQuick.Shapes

// Shared 24-unit line icons; no font glyphs or external assets.
Item {
    id: root
    property string kind: "dashboard"
    property color color: "#8ED4E8"
    implicitWidth: 24
    implicitHeight: 24
    readonly property var paths: ({
        toolbox: "M8 8V5Q8 3 10 3H14Q16 3 16 5V8 M5 8H19Q21 8 21 10V19Q21 21 19 21H5Q3 21 3 19V10Q3 8 5 8Z M3 13L10 15 M14 15L21 13 M10 13H14V17H10Z M7 18V21 M17 18V21",
        hud: "M12 2A10 10 0 1 0 12 22A10 10 0 1 0 12 2 M4 12H9 L12 14L15 12H20 M9 7H15 M10 18H14 M12 3V5",
        dashboard: "M3 19A10 10 0 1 1 21 19 M5 17L7 15 M4 11H7 M8 5L9 8 M16 5L15 8 M20 11H17 M12 14L17 9 M11 14A1 1 0 1 0 13 14A1 1 0 1 0 11 14 M7 21H17",
        pid: "M2 12H5 L7 5L10 19L13 8L16 15L18 12H22"
    })
    Item {
        width: 24; height: 24
        anchors.centerIn: parent
        scale: Math.min(root.width, root.height) / 24
        Shape {
            anchors.fill: parent
            visible: root.kind !== "tuning"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color
                strokeWidth: 1.6
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                fillColor: "transparent"
                PathSvg { path: root.paths[root.kind] || root.paths.dashboard }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: root.kind === "tuning"
            text: "PID"
            color: root.color; font.pixelSize: 13; font.bold: true
            font.family: ScreenTools.normalFontFamily
        }
    }
}
