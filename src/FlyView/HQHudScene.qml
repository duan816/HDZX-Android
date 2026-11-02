pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// Retained scene graph: telemetry moves existing geometry and glyphs. No
// GUI-thread Canvas rasterisation or full-image uploads on each attitude packet.
Item {
    id: scene
    required property var hud
    property real labelSize: 13
    readonly property bool connected: !!hud && !!hud.connected
    readonly property bool sampling: visible && !!hud && hud.visible && hud.expanded && connected
    property real roll: 0
    property real pitch: 0
    property real heading: NaN
    readonly property real headingPosition: isFinite(heading) ? heading : 0
    property real speed: NaN
    property real altitude: NaN
    property bool attitudeValid: false
    readonly property real centerX: width / 2
    readonly property real centerY: height * 0.47
    readonly property real bankRadius: Math.min(width * 0.32, height * 0.34)
    readonly property real extent: Math.hypot(width, height) + height * 2
    property int snapshots: 0
    clip: true

    function sample() {
        if (!sampling) return
        attitudeValid = !!hud.attitudeAvailable && isFinite(hud.rollAngle) && isFinite(hud.pitchAngle)
        roll = attitudeValid ? hud.rollAngle : 0
        pitch = attitudeValid ? Math.max(-90, Math.min(90, hud.pitchAngle)) : 0
        heading = Number(hud.heading)
        speed = Number(hud.groundSpeed)
        altitude = Number(hud.altitude)
        ++snapshots
    }
    function clearSample() {
        attitudeValid = false
        roll = 0
        pitch = 0
        heading = NaN
        speed = NaN
        altitude = NaN
    }
    onConnectedChanged: if (!connected) clearSample()
    Component.onCompleted: sample()
    onSamplingChanged: if (sampling) sample()
    Timer { interval: 40; repeat: true; running: scene.sampling; onTriggered: scene.sample() }

    component Ink: Text {
        color: "#FFFFFF"
        font.family: scene.hud ? scene.hud.roundedFont : ""
        font.pixelSize: scene.labelSize
        font.weight: Font.DemiBold
        style: Text.Outline
        styleColor: "#3A4651"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    Rectangle { anchors.fill: parent; color: "#27313A" }
    Item {
        x: scene.centerX; y: scene.centerY
        rotation: -scene.roll
        visible: scene.attitudeValid
        Item {
            y: scene.pitch * scene.height / 65
            Rectangle {
                x: -scene.extent; y: -scene.extent
                width: scene.extent * 2; height: scene.extent
                gradient: Gradient { GradientStop { position: 0; color: "#5367D1" } GradientStop { position: 1; color: "#98C8EC" } }
            }
            Rectangle {
                x: -scene.extent; width: scene.extent * 2; height: scene.extent
                gradient: Gradient { GradientStop { position: 0; color: "#95AB1C" } GradientStop { position: 1; color: "#5F7316" } }
            }
            Rectangle { x: -scene.extent; width: scene.extent * 2; height: 1.5; color: "#F7F8E9" }
            Repeater {
                model: [-80, -70, -60, -50, -40, -30, -20, -10, 10, 20, 30, 40, 50, 60, 70, 80]
                Item {
                    id: ladder
                    required property int modelData
                    readonly property real half: scene.width * (modelData % 20 === 0 ? 0.10 : 0.065)
                    y: -modelData * scene.height / 65
                    Rectangle { x: -ladder.half; width: ladder.half * 2; height: 1.3; color: "#E9F1EE" }
                    Ink { x: -ladder.half - width - scene.labelSize * 0.35; y: -height / 2; text: Math.abs(ladder.modelData) }
                    Ink { x: ladder.half + scene.labelSize * 0.35; y: -height / 2; text: Math.abs(ladder.modelData) }
                }
            }
        }
    }
    Shape {
        anchors.fill: parent
        visible: scene.attitudeValid
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "#E7EEF2"; strokeWidth: 1.4; fillColor: "transparent"
            PathAngleArc { centerX: scene.centerX; centerY: scene.centerY; radiusX: scene.bankRadius; radiusY: scene.bankRadius; startAngle: -150; sweepAngle: 120 }
        }
        ShapePath {
            strokeColor: "#EF301C"; strokeWidth: 2.5; fillColor: "transparent"
            PathSvg { path: "M" + (scene.centerX - scene.width * 0.18) + " " + scene.centerY + "h" + scene.width * 0.11
                + " M" + (scene.centerX - scene.width * 0.07) + " " + (scene.centerY + scene.height * 0.035)
                + " L" + scene.centerX + " " + (scene.centerY - scene.height * 0.008)
                + " L" + (scene.centerX + scene.width * 0.07) + " " + (scene.centerY + scene.height * 0.035)
                + " M" + (scene.centerX + scene.width * 0.07) + " " + scene.centerY + "h" + scene.width * 0.11 }
        }
    }
    Repeater {
        model: [-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60]
        Item {
            id: bankTick
            required property int modelData
            x: scene.centerX; y: scene.centerY
            rotation: modelData
            visible: scene.attitudeValid
            Rectangle { x: -0.7; y: -scene.bankRadius - height; width: 1.4; height: bankTick.modelData % 30 === 0 ? 9 : 5; color: "#E7EEF2" }
            Ink { x: -width / 2; y: -scene.bankRadius - 20 - height / 2; visible: bankTick.modelData !== 0 && bankTick.modelData % 30 === 0; text: Math.abs(bankTick.modelData); font.pixelSize: scene.labelSize * 0.9 }
        }
    }
    Item {
        x: scene.centerX; y: scene.centerY
        rotation: Math.max(-70, Math.min(70, scene.roll))
        visible: scene.attitudeValid
        Text { x: -width / 2; y: -scene.bankRadius - 6; text: "▼"; color: "#F8DE45"; font.pixelSize: scene.labelSize }
    }
    Ink { anchors.centerIn: parent; visible: !scene.attitudeValid; text: qsTr("姿态未上报") }

    Rectangle {
        anchors.top: parent.top; width: parent.width; height: Math.max(26, parent.height * 0.10); color: "#8A182B44"; clip: true
        Repeater {
            model: 25
            Item {
                id: headingTick
                required property int index
                readonly property real angle: Math.floor(scene.headingPosition / 5) * 5 + (index - 12) * 5
                x: scene.centerX + (angle - scene.headingPosition) * scene.width / 95
                visible: isFinite(scene.heading)
                Rectangle { width: 1; height: headingTick.angle % 15 === 0 ? 7 : 4; color: "#DBE8F3" }
                Ink {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 7
                    visible: headingTick.angle % 15 === 0
                    font.pixelSize: scene.labelSize * 0.85
                    text: { const a = (headingTick.angle % 360 + 360) % 360; return a % 90 === 0 ? ["N", "E", "S", "W"][a / 90] : a }
                }
            }
        }
    }
    Rectangle {
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
        width: scene.labelSize * 3.6; height: 23; color: "#DF102333"
        Ink { anchors.fill: parent; text: scene.hud ? scene.hud.headingText(scene.heading) : "--"; color: "#FFEB71" }
    }
    Repeater {
        model: [true, false]
        Item {
            id: tape
            required property bool modelData
            readonly property real value: modelData ? scene.speed : scene.altitude
            readonly property real position: isFinite(value) ? value : 0
            readonly property real span: scene.height * 0.46
            x: modelData ? 7 : scene.width - 57
            y: scene.height * 0.26
            width: 50; height: span
            Rectangle { anchors.fill: parent; color: "#63435975"; border.color: "#C7E3EF"; border.width: 1; clip: true
                Repeater {
                    model: 7
                    Item {
                        id: tapeTick
                        required property int index
                        readonly property real mark: Math.floor(tape.position / 5) * 5 + (index - 3) * 5
                        y: tape.span / 2 - (mark - tape.position) * tape.span / 20
                        visible: isFinite(tape.value)
                        width: parent.width
                        Rectangle { anchors.right: parent.right; width: 8; height: 1; color: "#DFECF2" }
                        Ink { anchors.horizontalCenter: parent.horizontalCenter; y: -height / 2; text: tapeTick.mark; font.pixelSize: scene.labelSize * 0.85 }
                    }
                }
            }
            Rectangle { x: -2; y: tape.span / 2 - 12; width: parent.width + 4; height: 24; color: "#ED101B27"
                Ink { anchors.fill: parent; text: scene.hud ? scene.hud.format(tape.value, 1) : "--" }
            }
            Ink { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height + 2; text: tape.modelData ? "m/s" : scene.hud && scene.hud.altitudeReference === 1 ? "AMSL m" : "REL m"; font.pixelSize: scene.labelSize * 0.75 }
        }
    }
}
