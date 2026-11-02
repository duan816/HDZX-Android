import QtQuick

import QGroundControl
import QGroundControl.Controls

/// Plan-only pin: its tip, rather than the number's center, is the geographic anchor.
Item {
    id: root

    property int index: 0
    property bool checked: false
    property bool home: index === 0
    property bool takeoff: false
    property real gimbalYaw: NaN
    property real vehicleYaw: NaN
    property bool showGimbalYaw: false
    signal clicked()

    // 40 px concept diameter at a 20 px font, reduced by the requested 20%.
    property real pinRadius: ScreenTools.defaultFontPixelHeight * 0.8
    readonly property real _padding: ScreenTools.defaultFontPixelWidth * 0.6
    readonly property real _yawMargin: showGimbalYaw ? ScreenTools.defaultFontPixelHeight : 0
    readonly property real anchorPointX: _padding + _yawMargin + pinRadius
    readonly property real _headY: _padding + _yawMargin + pinRadius
    readonly property real anchorPointY: _headY + pinRadius * 1.6
    readonly property color fillColor: checked ? palette.planWaypointSelected : home ? palette.planHome
                                             : takeoff ? palette.planTakeoff : palette.planWaypoint
    readonly property bool selectionAnimating: selectionPulse.running
    property bool _complete: false
    readonly property bool animationsEnabled: typeof mainWindow === "undefined" || mainWindow.hdzxNavigationAnimationsEnabled
    objectName: "hdzxPlanMarker_" + index

    width: 2 * (pinRadius + _padding + _yawMargin)
    height: anchorPointY + _padding + _yawMargin

    QGCPalette { id: palette }
    Connections {
        target: palette
        function onPaletteChanged() { pinCanvas.requestPaint() }
    }
    onCheckedChanged: {
        pinCanvas.requestPaint()
        selectionPulse.stop()
        selectionHalo.opacity = 0
        if (_complete && checked && visible && animationsEnabled) selectionPulse.restart()
    }
    onHomeChanged: pinCanvas.requestPaint()
    onTakeoffChanged: pinCanvas.requestPaint()
    onFillColorChanged: pinCanvas.requestPaint()
    onVisibleChanged: if (!visible) { selectionPulse.stop(); selectionHalo.opacity = 0 }
    onAnimationsEnabledChanged: if (!animationsEnabled) { selectionPulse.stop(); selectionHalo.opacity = 0 }
    onGimbalYawChanged: pinCanvas.requestPaint()
    onVehicleYawChanged: pinCanvas.requestPaint()
    onShowGimbalYawChanged: pinCanvas.requestPaint()
    Component.onCompleted: _complete = true

    // A single, cancellable pulse. Its screen transform never changes the map coordinate.
    Rectangle {
        id: selectionHalo
        x: root.anchorPointX - width / 2
        y: root._headY - height / 2
        width: root.pinRadius * 2.6
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1.5
        border.color: palette.planWaypointSelected
        opacity: 0
    }
    ParallelAnimation {
        id: selectionPulse
        NumberAnimation { target: selectionHalo; property: "scale"; from: 0.8; to: 1.65; duration: 360; easing.type: Easing.OutCubic }
        NumberAnimation { target: selectionHalo; property: "opacity"; from: 0.85; to: 0; duration: 360; easing.type: Easing.OutCubic }
    }

    Canvas {
        id: pinCanvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            const x = root.anchorPointX
            const y = root._headY
            const r = root.pinRadius
            ctx.clearRect(0, 0, width, height)
            if (root.showGimbalYaw && isFinite(root.gimbalYaw) && isFinite(root.vehicleYaw)) {
                const yaw = (root.vehicleYaw + root.gimbalYaw - 90) * Math.PI / 180
                ctx.beginPath()
                ctx.moveTo(x, root.anchorPointY)
                ctx.arc(x, root.anchorPointY, root._yawMargin, yaw - Math.PI / 4, yaw + Math.PI / 4)
                ctx.closePath()
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.65)
                ctx.fill()
            }
            ctx.beginPath()
            ctx.moveTo(x, root.anchorPointY)
            ctx.bezierCurveTo(x - r * 0.3, y + r * 0.9, x - r, y + r * 0.5, x - r, y)
            ctx.bezierCurveTo(x - r, y - r * 0.55, x - r * 0.55, y - r, x, y - r)
            ctx.bezierCurveTo(x + r * 0.55, y - r, x + r, y - r * 0.55, x + r, y)
            ctx.bezierCurveTo(x + r, y + r * 0.5, x + r * 0.3, y + r * 0.9, x, root.anchorPointY)
            ctx.closePath()
            ctx.fillStyle = root.fillColor
            ctx.fill()
            ctx.lineWidth = ScreenTools.defaultFontPixelWidth * 0.55
            ctx.strokeStyle = palette.planWaypointOutline
            ctx.stroke()
            ctx.lineWidth = ScreenTools.defaultFontPixelWidth * 0.22
            ctx.strokeStyle = palette.mapWidgetBorderLight
            ctx.stroke()
            if (root.checked) {
                ctx.beginPath()
                ctx.arc(x, y, r + root._padding * 0.6, 0, Math.PI * 2)
                ctx.lineWidth = ScreenTools.defaultFontPixelWidth * 0.2
                ctx.strokeStyle = palette.planWaypointSelected
                ctx.stroke()
            }
        }
    }

    QGCLabel {
        x: root.anchorPointX - root.pinRadius
        y: root._headY - root.pinRadius
        width: root.pinRadius * 2
        height: width
        text: root.home ? "H" : (root.takeoff ? "↑" : "") + root.index.toString()
        color: palette.planWaypointOutline
        font.bold: true
        font.pointSize: ScreenTools.defaultFontPointSize
        fontSizeMode: Text.Fit
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Item {
        id: tapTarget
        anchors.centerIn: parent
        width: Math.max(root.width, ScreenTools.minTouchPixels)
        height: Math.max(root.height, ScreenTools.minTouchPixels)
    }
    QGCMouseArea {
        fillItem: tapTarget
        onClicked: root.clicked()
    }
}
