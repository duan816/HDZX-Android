pragma ComponentBehavior: Bound
import QtQuick
import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    property real value: NaN
    property real maximum: 30
    property string unit: "m/s"
    property color accent: "#58E4D1"
    property var theme: ({face: "black", graph: 2, skin: "navigation"})
    readonly property bool whiteFace: theme.face === "white"
    readonly property bool horizontalMeter: theme.graph === 1 || theme.graph === 4 || theme.graph === 6 || theme.graph === 10
    readonly property bool valid: isFinite(value) && maximum > 0
    readonly property real fraction: valid ? Math.max(0, Math.min(1, value / maximum)) : 0
    readonly property bool frameReady: frame.painted && frame.paintedSkin === theme.skin
    objectName: "angularSpeedInstrument"
    implicitWidth: 230; implicitHeight: 230
    Canvas {
        id: frame
        property bool painted: false
        property string paintedSkin: ""
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            // Distinct silhouettes, not fifteen copies with recoloured rims.
            const frames = {
                1: [[.05,.18],[.95,.18],[.95,.82],[.05,.82]],
                2: [[.08,.1],[.9,.17],[.94,.7],[.64,.88],[.12,.79]],
                4: [[.08,.2],[.82,.2],[.96,.35],[.86,.78],[.18,.78],[.04,.63]],
                6: [[.05,.22],[.25,.1],[.75,.1],[.95,.22],[.95,.78],[.75,.9],[.25,.9],[.05,.78]],
                7: [[.12,.1],[.88,.1],[.88,.64],[.5,.9],[.12,.64]],
                8: [[.3,.08],[.7,.08],[.92,.3],[.92,.7],[.7,.92],[.3,.92],[.08,.7],[.08,.3]],
                10: [[.04,.32],[.22,.13],[.78,.13],[.96,.32],[.96,.68],[.78,.87],[.22,.87],[.04,.68]],
                11: [[.08,.18],[.45,.08],[.9,.26],[.92,.74],[.55,.92],[.1,.82]],
                12: [[.08,.08],[.8,.08],[.93,.35],[.82,.86],[.15,.94],[.06,.64]],
                13: [[.06,.14],[.28,.14],[.5,.25],[.72,.14],[.94,.14],[.87,.78],[.5,.94],[.13,.78]],
                14: [[.12,.32],[.5,.1],[.88,.32],[.88,.88],[.12,.88]]
            }
            const points = frames[root.theme.graph] || frames[2]
            const canvasWidth = width, canvasHeight = height
            ctx.beginPath()
            points.forEach(function(point, index) { if (index === 0) ctx.moveTo(point[0]*canvasWidth, point[1]*canvasHeight); else ctx.lineTo(point[0]*canvasWidth, point[1]*canvasHeight) })
            ctx.closePath()
            const gradient = ctx.createLinearGradient(0, 0, width, height)
            gradient.addColorStop(0, root.whiteFace ? "#FFFFFF" : root.theme.face === "red" ? "#9C263C" : "#263C4C")
            gradient.addColorStop(.48, root.whiteFace ? "#E0E5ED" : root.theme.face === "red" ? "#2E101D" : "#0D1C29")
            gradient.addColorStop(1, root.whiteFace ? "#AAB8C9" : "#03070D")
            ctx.fillStyle = gradient; ctx.fill(); ctx.strokeStyle = root.accent; ctx.lineWidth = 2; ctx.stroke()
            // Fine machining and reflective contours, painted only when the
            // size/theme changes. The live progress below stays GPU-native.
            ctx.save(); ctx.clip()
            for (let line = 0; line < 24; line++) {
                ctx.beginPath(); ctx.moveTo(width*.05, height*(.17+line*.027)); ctx.lineTo(width*.95,height*(.12+line*.027))
                ctx.lineWidth = .5; ctx.strokeStyle = root.whiteFace ? "rgba(255,255,255,0.21)" : "rgba(171,202,219,0.063)"; ctx.stroke()
            }
            const gloss = ctx.createLinearGradient(0, 0, 0, height*.65)
            gloss.addColorStop(0, root.whiteFace ? "rgba(255,255,255,0.4)" : "rgba(167,223,255,0.13)"); gloss.addColorStop(1, "rgba(255,255,255,0)")
            ctx.fillStyle = gloss; ctx.fillRect(0, 0, width, height*.43)
            ctx.restore()
            ctx.beginPath()
            points.forEach(function(point, index) { const x = (.5+(point[0]-.5)*.94)*canvasWidth, y = (.5+(point[1]-.5)*.94)*canvasHeight; if (index === 0) ctx.moveTo(x,y); else ctx.lineTo(x,y) })
            ctx.closePath(); ctx.lineWidth = .75; ctx.strokeStyle = root.whiteFace ? "rgba(109,131,151,0.31)" : "rgba(120,152,177,0.33)"; ctx.stroke()
            ctx.beginPath()
            if (root.horizontalMeter) { ctx.moveTo(width*.2,height*.75); ctx.lineTo(width*.8,height*.75) }
            else { ctx.moveTo(width * 0.19, height * 0.2); ctx.lineTo(width * 0.21, height * 0.7) }
            ctx.strokeStyle = root.whiteFace ? "#728FA0" : "#456A80"; ctx.lineWidth = 1; ctx.stroke()
            painted = true
            paintedSkin = root.theme.skin
        }
    }
    onAccentChanged: frame.requestPaint()
    onThemeChanged: frame.requestPaint()
    onVisibleChanged: if (visible) frame.requestPaint()
    Component.onCompleted: frame.requestPaint()
    Rectangle {
        id: meter
        x: root.width * (root.horizontalMeter ? .2 : .145)
        y: root.height * (root.horizontalMeter ? .73 : .27)
        width: root.width * (root.horizontalMeter ? .6 : .029)
        height: root.height * (root.horizontalMeter ? .018 : .44)
        radius: Math.min(width,height)/2
        color: root.whiteFace ? "#728493" : "#233748"
        Rectangle {
            anchors.left: parent.left; anchors.bottom: parent.bottom
            width: root.horizontalMeter ? parent.width*root.fraction : parent.width
            height: root.horizontalMeter ? parent.height : parent.height*root.fraction
            radius: parent.radius
            gradient: Gradient { orientation: root.horizontalMeter ? Gradient.Horizontal : Gradient.Vertical; GradientStop { position: 0; color: root.accent } GradientStop { position: 1; color: Qt.lighter(root.accent,1.4) } }
            Behavior on width { NumberAnimation { duration: 100 } }
            Behavior on height { NumberAnimation { duration: 100 } }
        }
    }
    Column {
        x: root.width * (root.horizontalMeter ? .18 : .23); y: root.height * .30; width: root.width * .63; spacing: root.height * .014
        QGCLabel { width: parent.width; text: root.valid ? root.value.toFixed(1) : "--"; color: root.whiteFace ? "#162637" : "#E6F9FF"; font.pixelSize: Math.max(16, root.width * .22); font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; fontSizeMode: Text.Fit; minimumPixelSize: 12 }
        QGCLabel { width: parent.width; text: root.unit; color: root.whiteFace ? "#345566" : root.accent; font.pixelSize: Math.max(11, root.width * .065); horizontalAlignment: Text.AlignHCenter }
    }
    QGCLabel { x: root.width*.2; y: root.height*.19; width: root.width*.6; text: root.theme.skin.toUpperCase(); color: root.whiteFace ? "#436176" : root.accent; font.pixelSize: Math.max(8,root.width*.034); horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
    QGCLabel { x: root.width*.22; y: root.height*.855; width: root.width*.6; text: "0 — " + root.maximum; color: root.whiteFace ? "#AEC4D2" : "#ABC5D1"; font.pixelSize: Math.max(10,root.width*.05); horizontalAlignment: Text.AlignHCenter }
}
