pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    property real fraction: NaN
    property bool critical: false
    property string valueText: "--"
    property string caption: ""
    property color accentColor: "#56DB99"
    property bool instrumentStyle: false
    property bool compassStyle: false
    property string centerSymbol: ""
    property string minimumText: ""
    property string maximumText: ""
    readonly property real diameter: Math.min(width, height)
    readonly property real stroke: Math.max(3, diameter * (instrumentStyle ? 0.058 : 0.10))
    readonly property real arcRadius: diameter * (instrumentStyle ? 0.38 : 0.44)
    readonly property real startAngle: compassStyle ? -90 : instrumentStyle ? 135 : -90
    readonly property real sweepAngle: compassStyle || !instrumentStyle ? 360 : 270
    readonly property real needleAngle: startAngle + sweepAngle * displayedFraction
    readonly property bool valid: isFinite(fraction) && fraction >= 0 && fraction <= 1
    property real displayedFraction: 0
    implicitWidth: ScreenTools.defaultFontPixelHeight * 2.6
    implicitHeight: implicitWidth
    function refreshFraction() {
        levelAnimation.stop()
        const available = isFinite(fraction) && fraction >= 0 && fraction <= 1
        if (!available || critical || (compassStyle && Math.abs(fraction - displayedFraction) > 0.5)) {
            displayedFraction = available ? fraction : 0
        } else {
            levelAnimation.to = fraction
            levelAnimation.start()
        }
    }
    onFractionChanged: refreshFraction()
    onCriticalChanged: if (critical) refreshFraction()
    Component.onCompleted: displayedFraction = valid ? fraction : 0
    NumberAnimation { id: levelAnimation; target: root; property: "displayedFraction"; duration: 190; easing.type: Easing.OutCubic }
    Shape {
        preferredRendererType: Shape.CurveRenderer
        anchors.fill: parent
        ShapePath {
            strokeWidth: root.stroke
            strokeColor: "#294452"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: root.startAngle
                sweepAngle: root.sweepAngle
            }
        }
        ShapePath {
            strokeWidth: root.stroke
            strokeColor: root.valid && root.displayedFraction > 0 ? root.accentColor : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: root.startAngle
                sweepAngle: root.sweepAngle * root.displayedFraction
            }
        }
    }
    Repeater {
        model: root.instrumentStyle ? (root.compassStyle ? 24 : 31) : 0
        delegate: Rectangle {
            required property int index
            readonly property real angle: (root.startAngle + root.sweepAngle * index / (root.compassStyle ? 24 : 30)) * Math.PI / 180
            width: index % 5 === 0 ? Math.max(2, root.diameter * 0.014) : 1
            height: root.diameter * (index % 5 === 0 ? 0.058 : 0.033)
            x: root.width / 2 + Math.cos(angle) * root.diameter * 0.465 - width / 2
            y: root.height / 2 + Math.sin(angle) * root.diameter * 0.465 - height / 2
            rotation: angle * 180 / Math.PI + 90
            radius: 1
            color: root.valid && index / (root.compassStyle ? 24 : 30) <= root.displayedFraction ? root.accentColor : "#547182"
        }
    }
    Item {
        objectName: "gaugeNeedle"
        anchors.centerIn: parent
        width: root.diameter
        height: width
        visible: root.instrumentStyle && root.valid
        rotation: root.needleAngle
        Rectangle {
            // Peripheral pointer leaves the numeric readout unobstructed.
            x: parent.width * 0.77; y: parent.height / 2 - height / 2
            width: parent.width * 0.14; height: Math.max(2, parent.width * 0.028)
            radius: height / 2; color: root.accentColor
        }
    }
    Repeater {
        model: root.compassStyle && root.diameter >= 90 ? ["N", "E", "S", "W"] : []
        delegate: QGCLabel {
            required property int index
            required property string modelData
            readonly property real angle: (index * 90 - 90) * Math.PI / 180
            text: modelData
            x: root.width / 2 + Math.cos(angle) * root.diameter * 0.28 - width / 2
            y: root.height / 2 + Math.sin(angle) * root.diameter * 0.28 - height / 2
            color: index === 0 ? "#F6C474" : "#8CA3B3"
            font.pixelSize: root.diameter * 0.075
        }
    }
    Column {
        anchors.centerIn: parent
        spacing: root.diameter * 0.02
        QGCLabel {
            visible: root.centerSymbol !== "" && root.diameter >= 90
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.centerSymbol
            color: root.valid ? root.accentColor : "#8CA3B3"
            font.pixelSize: root.diameter * 0.11
        }
        QGCLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.valid ? root.valueText : "--"
            color: root.valid ? root.accentColor : "#8CA3B3"
            font.pixelSize: Math.max(10, root.diameter * (root.diameter >= 90 ? 0.185 : 0.265))
            font.weight: Font.DemiBold
        }
        QGCLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.caption
            color: "#B4CBD9"
            font.pixelSize: Math.max(8, root.diameter * 0.10)
        }
    }
    QGCLabel {
        visible: root.instrumentStyle && !root.compassStyle && root.diameter >= 90
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height / 2 + root.diameter * 0.32
        text: root.minimumText + " · " + root.maximumText
        color: "#8CA3B3"
        font.pixelSize: root.diameter * 0.075
    }
}
