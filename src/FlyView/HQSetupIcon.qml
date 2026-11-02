import QtQuick
import QtQuick.Shapes
Item {
    id: root
    property string kind: "overview"
    property color color: "#61D9D1"
    readonly property var paths: ({
        overview:"M3 3H10V10H3Z M14 3H21V10H14Z M3 14H10V21H3Z M14 14H21V21H14Z",
        sensors:"M12 2V6 M12 18V22 M2 12H6 M18 12H22 M12 6A6 6 0 1 0 12 18A6 6 0 1 0 12 6 M12 10A2 2 0 1 0 12 14A2 2 0 1 0 12 10",
        radio:"M6 7H18Q20 7 21 11L22 18Q21 21 18 18L16 16H8L6 18Q3 21 2 18L3 11Q4 7 6 7 M6 12H10 M8 10V14 M16 11H17 M18 13H19",
        mode:"M3 18L9 12L14 16L21 5 M15 5H21V11",
        power:"M3 7H19V18H3Z M19 10H22V15H19 M10 9L7 13H12L10 16",
        safety:"M12 2L20 6V12Q19 19 12 22Q5 19 4 12V6Z M8 12L11 15L16 9",
        tuning:"M5 2V7 M5 11V22 M3 7H7V11H3Z M12 2V13 M12 17V22 M10 13H14V17H10Z M19 2V5 M19 9V22 M17 5H21V9H17Z",
        parameters:"M3 5H5 M9 5H21 M3 12H5 M9 12H21 M3 19H5 M9 19H21",
        ai:"M3 19L8 5L13 19 M5 14H11 M16 5H21 M18.5 5V19 M16 19H21"
    })
    Item {
        width:24; height:24; anchors.centerIn:parent
        scale: Math.min(root.width,root.height)/24
        Shape {
            anchors.fill:parent
            ShapePath { strokeColor:root.color; strokeWidth:1.7; fillColor:"transparent"; capStyle:ShapePath.RoundCap; joinStyle:ShapePath.RoundJoin; PathSvg { path:root.paths[root.kind] || root.paths.overview } }
        }
    }
}
