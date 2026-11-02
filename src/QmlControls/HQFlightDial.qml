pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    property real value: NaN
    property real minimum: 0
    property real maximum: 30
    property int majorIntervals: 6
    property string valueText: "--"
    property string unit: "m/s"
    property bool compass: false
    property string skin: "neutral"
    property color accent: "#65DCEF"
    property string badge: ""
    property string detail: ""
    property string modeToken: ""
    property bool animationsEnabled: true
    readonly property bool classic: skin === "classic" || skin === "precision" || skin === "sport"
    readonly property bool performance: skin === "performance"
    readonly property color dialText: classic ? "#162332" : "#F7F8F5"
    readonly property bool valid: isFinite(value) && maximum > minimum
    readonly property real fraction: valid ? Math.max(0, Math.min(1, (value - minimum) / (maximum - minimum))) : NaN
    readonly property real diameter: Math.min(width, height)
    readonly property bool frameReady: engraving.painted && engraving.paintedSkin === skin
    readonly property real startAngle: compass ? -90 : skin === "return" || skin === "orbit" ? 180 : skin === "precision" || skin === "external" || skin === "follow" ? 120 : skin === "navigation" ? 150 : skin === "mission" ? 157.5 : skin === "sport" ? 140 : 135
    readonly property real sweepAngle: compass ? 360 : skin === "return" ? 180 : skin === "orbit" || skin === "precision" || skin === "external" || skin === "follow" ? 300 : skin === "navigation" ? 240 : skin === "mission" ? 225 : skin === "sport" ? 260 : 270
    readonly property int intervals: compass ? 12 : Math.max(2, majorIntervals)
    readonly property real needleFraction: displayedFraction + (1 - displayedFraction) * introductionBlend
    readonly property real needleAngle: startAngle + sweepAngle * needleFraction
    readonly property bool introductionRunning: introduction.running
    property real introductionBlend: 0
    property string previousModeToken: ""
    property bool ready: false
    property real displayedFraction: 0
    implicitWidth: 220
    implicitHeight: implicitWidth

    function tickText(index) {
        if (compass) return ["N", "30", "60", "E", "120", "150", "S", "210", "240", "W", "300", "330"][index]
        const reading = minimum + (maximum - minimum) * index / intervals
        return Math.abs(reading - Math.round(reading)) < 0.001 ? String(Math.round(reading)) : reading.toFixed(1)
    }
    function retarget() {
        motion.stop()
        if (!valid) resetIntroduction()
        if (!valid || (compass && Math.abs(fraction - displayedFraction) > 0.5)) displayedFraction = valid ? fraction : 0
        else { motion.to = fraction; motion.start() }
    }
    function resetIntroduction() { introduction.stop(); introductionBlend = 0 }
    function changedMode() {
        resetIntroduction()
        if (ready && previousModeToken && modeToken && modeToken !== "neutral" && previousModeToken !== modeToken && animationsEnabled && visible && valid && !compass) introduction.start()
        previousModeToken = modeToken
    }
    onFractionChanged: retarget()
    onModeTokenChanged: changedMode()
    onAnimationsEnabledChanged: if (!animationsEnabled) { resetIntroduction(); retarget() }
    onVisibleChanged: if (!visible) resetIntroduction()
    Component.onCompleted: { displayedFraction = valid ? fraction : 0; previousModeToken = modeToken; ready = true }
    NumberAnimation { id: motion; target: root; property: "displayedFraction"; duration: root.animationsEnabled ? 160 : 0; easing.type: Easing.OutCubic }
    // Only the decorative needle introduces the new theme. Numeric telemetry
    // remains live, and the return follows the latest reading, not a snapshot.
    SequentialAnimation {
        id: introduction
        NumberAnimation { target: root; property: "introductionBlend"; to: 1; duration: 360; easing.type: Easing.InOutCubic }
        PauseAnimation { duration: 60 }
        NumberAnimation { target: root; property: "introductionBlend"; to: 0; duration: 460; easing.type: Easing.InOutCubic }
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.diameter * 0.99; height: width; radius: width / 2
        gradient: Gradient { GradientStop { position: 0; color: "#737C85" } GradientStop { position: 0.5; color: "#141B22" } GradientStop { position: 1; color: "#8C969C" } }
    }
    Rectangle {
        anchors.centerIn: parent
        width: root.diameter * 0.968; height: width; radius: width / 2
        gradient: Gradient { GradientStop { position: 0; color: root.classic ? "#FFFFFF" : root.performance ? "#3E0E1B" : "#18232D" } GradientStop { position: 0.58; color: root.classic ? "#E7EAEF" : "#070D13" } GradientStop { position: 1; color: root.classic ? "#BAC3CD" : "#131F2B" } }
        border.width: 1; border.color: "#AFBAC1"
    }
    Canvas {
        id: engraving
        property bool painted: false
        property string paintedSkin: ""
        anchors.fill: parent
        Component.onCompleted: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onPaint: {
            const ctx = getContext("2d"), d = root.diameter, cx = width / 2, cy = height / 2
            const start = root.startAngle * Math.PI / 180, end = (root.startAngle + root.sweepAngle) * Math.PI / 180
            ctx.clearRect(0, 0, width, height)
            const band = ctx.createLinearGradient(0, cy - d * .44, 0, cy + d * .44)
            band.addColorStop(0, root.classic ? "#FAF8F6" : root.performance ? "#DB293E" : root.skin === "offboard" ? "#1E8757" : root.skin === "navigation" ? "#222A31" : "#304857")
            band.addColorStop(.5, root.classic ? "#DFE1E7" : root.performance ? "#8C1428" : root.skin === "offboard" ? "#0B4432" : root.skin === "navigation" ? "#05080C" : "#172B39")
            band.addColorStop(1, root.classic ? "#B8C2CD" : root.skin === "offboard" ? "#052D21" : "#0B1420")
            ctx.beginPath(); ctx.arc(cx, cy, d*.366, start, end); ctx.lineWidth = d*.169; ctx.strokeStyle = band; ctx.stroke()
            // Fine concentric engraving is static: no per-telemetry repaint.
            for (let i = 0; i < 18; i++) {
                ctx.beginPath(); ctx.arc(cx, cy, d*(.286+i*.0085), start, end)
                ctx.strokeStyle = i%2 ? (root.classic ? "rgba(255,255,255,0.31)" : "rgba(214,231,240,0.067)") : (root.classic ? "rgba(113,134,153,0.15)" : "rgba(0,0,0,0.19)")
                ctx.lineWidth = Math.max(.45, d*.002); ctx.stroke()
            }
            for (const radius of [.466, .475]) {
                ctx.beginPath(); ctx.arc(cx, cy, d*radius, start, end)
                ctx.strokeStyle = root.classic ? "#F9FCFF" : "#B7CFDA"; ctx.lineWidth = d*.003; ctx.stroke()
            }
            // Accent zones are mode styling, not made-up speed warning limits.
            ctx.beginPath(); ctx.arc(cx, cy, d*.459, end-.37, end)
            ctx.strokeStyle = root.accent; ctx.lineWidth = d*.012; ctx.stroke()
            ctx.beginPath(); ctx.arc(cx, cy, d*.282, start, end)
            ctx.strokeStyle = root.accent; ctx.lineWidth = d*.004; ctx.stroke()
            painted = true
            paintedSkin = root.skin
        }
    }
    Connections {
        target: root
        function onSkinChanged() { engraving.requestPaint() }
        function onAccentChanged() { engraving.requestPaint() }
        function onStartAngleChanged() { engraving.requestPaint() }
        function onSweepAngleChanged() { engraving.requestPaint() }
    }
    Shape {
        preferredRendererType: Shape.CurveRenderer
        anchors.fill: parent
        ShapePath {
            strokeWidth: root.diameter * 0.017
            strokeColor: root.accent
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.diameter * 0.478; radiusY: radiusX; startAngle: root.startAngle; sweepAngle: root.valid ? root.sweepAngle * root.displayedFraction : 0 }
        }
        ShapePath {
            strokeWidth: 1
            strokeColor: root.classic ? "#607789" : root.accent
            fillColor: "transparent"
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.diameter * 0.455; radiusY: radiusX; startAngle: root.startAngle; sweepAngle: root.sweepAngle }
        }
    }
    Repeater {
        model: root.compass ? root.intervals * 4 : root.intervals * 4 + 1
        delegate: Rectangle {
            required property int index
            readonly property real angle: (root.startAngle + root.sweepAngle * index / (root.intervals * 4)) * Math.PI / 180
            width: index % 4 === 0 ? Math.max(2, root.diameter * 0.012) : 1
            height: root.diameter * (index % 4 === 0 ? 0.056 : 0.025)
            x: root.width / 2 + Math.cos(angle) * root.diameter * 0.432 - width / 2
            y: root.height / 2 + Math.sin(angle) * root.diameter * 0.432 - height / 2
            rotation: angle * 180 / Math.PI + 90
            color: root.dialText
        }
    }
    Repeater {
        objectName: "numberedDialTicks"
        model: root.compass ? root.intervals : root.intervals + 1
        delegate: QGCLabel {
            required property int index
            readonly property real angle: (root.startAngle + root.sweepAngle * index / root.intervals) * Math.PI / 180
            objectName: "dialTick" + index
            text: root.tickText(index)
            x: root.width / 2 + Math.cos(angle) * root.diameter * 0.342 - width / 2
            y: root.height / 2 + Math.sin(angle) * root.diameter * 0.342 - height / 2
            color: root.dialText
            font.pixelSize: Math.max(9, root.diameter * 0.057)
            font.weight: Font.DemiBold
        }
    }
    Item {
        objectName: "flightDialNeedle"
        anchors.centerIn: parent; width: root.diameter; height: width
        rotation: root.needleAngle
        visible: root.valid
        Shape {
            preferredRendererType: Shape.CurveRenderer
            anchors.fill: parent
            ShapePath {
                strokeWidth: 1; strokeColor: "#FFADA4"; fillColor: "#EC384D"
                startX: root.diameter*.62; startY: root.diameter*.4825
                PathLine { x: root.diameter*.946; y: root.diameter*.5 }
                PathLine { x: root.diameter*.62; y: root.diameter*.5175 }
                PathLine { x: root.diameter*.62; y: root.diameter*.4825 }
            }
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: root.diameter * 0.55; height: width; radius: width / 2
        gradient: Gradient { GradientStop { position: 0; color: "#141E29" } GradientStop { position: 0.6; color: "#050A10" } GradientStop { position: 1; color: root.performance ? "#4D1221" : root.classic ? "#2C2027" : "#0C2030" } }
        border.color: root.classic ? "#748CA1" : root.accent; border.width: 1
        Column {
            anchors.centerIn: parent
            width: parent.width * .88; spacing: root.diameter * 0.018
            QGCLabel { width: parent.width; text: root.badge; color: root.accent; font.pixelSize: Math.max(8, root.diameter*.034); horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; visible: text.length > 0 }
            QGCLabel { objectName: "flightDialLiveValue"; width: parent.width; text: root.valid ? root.valueText : "--"; color: root.valid ? "#FFFFFF" : "#8F9EAB"; font.pixelSize: root.diameter * 0.175; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; fontSizeMode: Text.Fit; minimumPixelSize: 12 }
            QGCLabel { width: parent.width; text: root.unit; color: "#CBDCE6"; font.pixelSize: Math.max(9, root.diameter * 0.065); horizontalAlignment: Text.AlignHCenter }
        }
    }
    QGCLabel {
        x: (root.width-width)/2; y: (root.height-root.diameter)/2+root.diameter*.805
        width: root.diameter*.55; horizontalAlignment: Text.AlignHCenter
        text: root.detail; color: root.classic ? "#20384A" : root.accent
        font.pixelSize: Math.max(8, root.diameter*.04); elide: Text.ElideRight
        visible: text.length > 0 && !root.compass
    }
    QGCLabel { anchors.bottom: parent.bottom; anchors.bottomMargin: root.diameter*.014; anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("模式动效 · 数字为实时值"); color: root.classic ? "#34475B" : "#CDE6ED"; font.pixelSize: Math.max(8,root.diameter*.031); visible: root.introductionRunning }
}
