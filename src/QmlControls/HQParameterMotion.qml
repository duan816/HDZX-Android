import QtQuick

// The model and Fact edit path update independently of the visual reveal.
Item {
    id: root
    required property Item targetItem
    property bool animationsEnabled: true
    property real foldDegrees: 0
    property real travel: 10
    property real initialScale: 0.992
    property real initialOpacity: 0.76
    property int duration: 240
    property real progress: 1
    readonly property real angle: foldDegrees * (1 - progress)
    readonly property real offset: travel * (1 - progress)
    readonly property real surfaceScale: initialScale + (1 - initialScale) * progress
    readonly property bool animating: arrival.running

    function settle() { arrival.stop(); progress = 1 }
    function reveal() {
        if (!animationsEnabled || !targetItem.visible) { settle(); return }
        const interrupted = arrival.running
        arrival.stop()
        progress = interrupted ? Math.min(progress, 0.45) : 0
        arrival.start()
    }
    onAnimationsEnabledChanged: if (!animationsEnabled) settle()
    Binding {
        target: root.targetItem
        property: "opacity"
        value: root.initialOpacity + (1 - root.initialOpacity) * root.progress
    }
    Connections {
        target: root.targetItem
        function onVisibleChanged() {
            if (root.targetItem.visible) root.reveal()
            else root.settle()
        }
    }
    NumberAnimation {
        id: arrival
        target: root
        property: "progress"
        to: 1
        duration: root.duration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
    }
}
