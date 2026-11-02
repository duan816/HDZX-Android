import QtQuick

// Decorative only: observe the existing button signals, never intercept input
// or delay an action. A single ripple is restarted on rapid repeated presses.
Item {
    id: root
    required property var control
    property color rippleColor: "#78A9C5"
    property real originX: 0
    property real originY: 0
    property real progress: 0
    property real strength: 0
    property real edgeProgress: 0
    property real edgeStrength: 0
    property bool animationsEnabled: true
    property bool observePressedProperty: false
    readonly property bool animating: ripple.running
    anchors.fill: parent
    clip: true
    visible: strength > 0 || edgeStrength > 0

    function settle() {
        ripple.stop()
        strength = 0
        edgeStrength = 0
        progress = 0
        edgeProgress = 0
    }
    onAnimationsEnabledChanged: if (!animationsEnabled) settle()
    function startRipple() {
        if (!animationsEnabled || !control.enabled || !control.visible) return
        const px = control.pressX !== undefined ? control.pressX : control.mouseX !== undefined ? control.mouseX : control.width / 2
        const py = control.pressY !== undefined ? control.pressY : control.mouseY !== undefined ? control.mouseY : control.height / 2
        const point = control.mapToItem !== undefined ? mapFromItem(control, px, py) : Qt.point(width / 2, height / 2)
        originX = point.x
        originY = point.y
        ripple.restart()
    }

    Rectangle {
        width: root.progress * Math.sqrt(root.width * root.width + root.height * root.height) * 2
        height: width
        radius: width / 2
        x: root.originX - width / 2
        y: root.originY - height / 2
        color: root.rippleColor
        opacity: root.strength
    }

    Connections {
        target: root.control
        ignoreUnknownSignals: true
        function onPressed() { if (!root.observePressedProperty) root.startRipple() }
        function onPressedChanged() { if (root.observePressedProperty && root.control.pressed) root.startRipple() }
        function onEnabledChanged() { if (!root.control.enabled) root.settle() }
        function onVisibleChanged() { if (!root.control.visible) root.settle() }
    }
    ParallelAnimation {
        id: ripple
        NumberAnimation { target: root; property: "progress"; from: 0; to: 1; duration: 540; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "strength"; from: 0.22; to: 0; duration: 540; easing.type: Easing.OutQuad }
    }
}
