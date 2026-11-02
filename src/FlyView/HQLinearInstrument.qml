pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QGroundControl
import QGroundControl.Controls

// Altitude scrolls past a fixed reference index; climb uses a signed scale.
// No invented zero, target height or terrain clearance when telemetry is absent.
Rectangle {
    id: root
    property real value: NaN
    property bool verticalSpeed: false
    property bool animationsEnabled: true
    property color accent: "#69D7F6"
    readonly property bool valid: isFinite(value)
    readonly property real metric: Math.min(width, height)
    readonly property real tapeSpan: 80
    readonly property real centerReading: valid ? value : 0
    objectName: verticalSpeed ? "climbBarInstrument" : "altitudeTapeInstrument"
    radius: metric * 0.055; border.color: "#557384"
    implicitWidth: ScreenTools.defaultFontPixelHeight * 13
    implicitHeight: ScreenTools.defaultFontPixelHeight * 14
    gradient: Gradient {
        GradientStop { position: 0; color: "#243C4D" }
        GradientStop { position: 0.32; color: "#0D1B28" }
        GradientStop { position: 1; color: "#07121D" }
    }
    clip: true
    Rectangle {
        anchors.fill: parent; anchors.margins: root.metric * 0.018
        radius: root.radius * 0.8; color: "transparent"; border.color: "#314E60"
    }
    Rectangle { x: root.width * 0.07; y: root.height * 0.09; width: root.metric * 0.012; height: root.metric * 0.075; radius: width / 2; color: root.accent }
    QGCLabel {
        x: root.width * 0.11; y: root.height * 0.075
        text: root.verticalSpeed ? qsTr("垂直速度") : qsTr("相对高度")
        color: "#E6F4F9"; font.pixelSize: root.metric * 0.060; font.weight: Font.DemiBold
    }
    QGCLabel {
        anchors.right: parent.right; anchors.rightMargin: root.width * 0.07
        y: root.height * 0.09; text: root.verticalSpeed ? "V/S" : "ALT REL"
        color: root.accent; font.pixelSize: root.metric * 0.038; font.letterSpacing: root.metric * 0.003
    }
    Rectangle { x: root.width * 0.07; y: root.height * 0.165; width: root.width * 0.86; height: 1; color: "#365468" }
    Rectangle {
        id: tape
        objectName: "linearInstrumentTape"
        x: root.width * 0.075; y: root.height * 0.205
        width: root.width * 0.40; height: root.height * 0.59
        color: "#142C3C"; radius: root.metric * 0.025
        clip: true
        Rectangle { anchors.right: parent.right; width: parent.width * 0.055; height: parent.height; color: "#2E5266" }
        Repeater {
            model: root.valid ? (root.verticalSpeed ? 21 : 45) : 0
            delegate: Item {
                id: tickItem
                required property int index
                readonly property real tick: root.verticalSpeed ? 10 - index : (Math.floor(root.centerReading / 2) + 22 - index) * 2
                readonly property bool major: tick % (root.verticalSpeed ? 5 : 10) === 0
                width: tape.width
                height: root.metric * 0.07
                y: tape.height / 2 + (root.verticalSpeed ? -tick * tape.height * 0.045 : (root.centerReading - tick) * tape.height / root.tapeSpan) - height / 2
                Rectangle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * (tickItem.major ? 0.25 : 0.12)
                    height: tickItem.major ? Math.max(1.5, root.metric * 0.005) : 1
                    color: tickItem.major ? "#CAE7F3" : "#678B9F"
                }
                QGCLabel {
                    visible: tickItem.major
                    anchors.left: parent.left; anchors.leftMargin: root.width * 0.025
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.69; height: parent.height
                    text: tickItem.tick; color: "#DAEDF4"
                    font.pixelSize: root.metric * 0.066; font.weight: Font.Medium
                    fontSizeMode: Text.Fit; minimumPixelSize: 8; verticalAlignment: Text.AlignVCenter
                }
            }
        }
        Rectangle {
            visible: root.verticalSpeed && root.valid
            x: tape.width * 0.66; width: tape.width * 0.07
            y: root.value >= 0 ? tape.height * (0.5 - Math.min(10, root.value) * 0.045) : tape.height / 2
            height: Math.abs(Math.max(-10, Math.min(10, root.value))) * tape.height * 0.045
            radius: width / 2; color: root.value < 0 ? "#FFBA6A" : root.accent
        }
        Rectangle {
            width: parent.width; height: parent.height * 0.19
            gradient: Gradient { GradientStop { position: 0; color: "#142C3C" } GradientStop { position: 1; color: "#00142C3C" } }
        }
        Rectangle {
            anchors.bottom: parent.bottom; width: parent.width; height: parent.height * 0.19
            gradient: Gradient { GradientStop { position: 0; color: "#00142C3C" } GradientStop { position: 1; color: "#142C3C" } }
        }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: root.accent; opacity: root.valid ? 0.6 : 0.2 }
    }
    Rectangle {
        id: readout
        x: root.width * 0.47; y: tape.y + tape.height / 2 - height / 2
        width: root.width * 0.455; height: root.height * 0.25
        radius: root.metric * 0.028; border.color: root.valid ? root.accent : "#577082"
        gradient: Gradient { GradientStop { position: 0; color: "#213C50" } GradientStop { position: 0.45; color: "#102333" } GradientStop { position: 1; color: "#081723" } }
        Rectangle { x: parent.width * 0.07; y: parent.height * 0.06; width: parent.width * 0.86; height: 1; color: root.accent; opacity: 0.3 }
        HQAnimatedNumber {
            objectName: "linearInstrumentLiveValue"
            anchors.centerIn: parent; width: parent.width * 0.92; height: parent.height * 0.82
            value: root.value; animationsEnabled: root.animationsEnabled
            travel: font.pixelSize * 0.06; jumpScale: 1.012
            color: root.valid ? "#F2FCFF" : "#8DA7B7"
            font.pixelSize: root.metric * 0.15; font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            fontSizeMode: Text.Fit; minimumPixelSize: 12
        }
    }
    Shape {
        x: readout.x - root.width * 0.046; y: readout.y + readout.height / 2 - root.metric * 0.028
        width: root.width * 0.046; height: root.metric * 0.056
        ShapePath {
            strokeWidth: 0; fillColor: root.valid ? root.accent : "#577082"
            startX: 0; startY: root.metric * 0.028
            PathLine { x: root.width * 0.046; y: 0 }
            PathLine { x: root.width * 0.046; y: root.metric * 0.056 }
            PathLine { x: 0; y: root.metric * 0.028 }
        }
    }
    QGCLabel {
        x: readout.x; y: readout.y - height - root.height * 0.035; width: readout.width
        text: root.verticalSpeed ? "VERTICAL SPEED" : "RELATIVE ALTITUDE"
        color: "#87A8BB"; font.pixelSize: root.metric * 0.034; horizontalAlignment: Text.AlignHCenter
    }
    QGCLabel {
        x: readout.x; y: readout.y + readout.height + root.height * 0.025; width: readout.width
        text: root.verticalSpeed ? "m/s" : "m"; color: root.accent
        font.pixelSize: root.metric * 0.062; horizontalAlignment: Text.AlignHCenter
    }
    Rectangle { x: root.width * 0.07; y: root.height * 0.835; width: root.width * 0.86; height: 1; color: "#365468" }
    QGCLabel {
        x: root.width * 0.07; y: root.height * 0.875; width: root.width * 0.86
        text: !root.valid ? qsTr("等待数据 / 数据已过期") : root.verticalSpeed ? (root.value > 0 ? qsTr("↑ 上升") : root.value < 0 ? qsTr("↓ 下降") : qsTr("水平飞行")) : qsTr("高度基准 · 起飞点")
        color: "#A6C0CF"; font.pixelSize: root.metric * 0.044; horizontalAlignment: Text.AlignHCenter
    }
}
