pragma ComponentBehavior: Bound

import QtQuick
import QGroundControl.Controls

// The text always binds to the latest telemetry. Only its position/scale moves;
// skipped waypoint IDs and intermediate measurements are never fabricated.
QGCLabel {
    id: root
    property real value: NaN
    property int decimals: 1
    property string prefix: ""
    property string suffix: ""
    property bool animationsEnabled: true
    property int minimumInterval: 650
    property real travel: font.pixelSize * 0.12
    property real jumpScale: 1.025
    readonly property bool valid: isFinite(value)
    readonly property bool animating: jump.running
    property real _offset: 0
    property real _zoom: 1
    property real _previous: NaN
    property double _lastAnimation: 0
    property bool _ready: false
    text: prefix + (valid ? value.toFixed(decimals) : "--") + suffix
    transform: [Translate { y: root._offset }, Scale {
        origin.x: root.width / 2; origin.y: root.height / 2
        xScale: root._zoom; yScale: root._zoom
    }]

    function settle() { jump.stop(); _offset = 0; _zoom = 1 }
    function updateReading() {
        const now = Date.now()
        const available = isFinite(value)
        const changed = available && isFinite(_previous) && value.toFixed(decimals) !== _previous.toFixed(decimals)
        if (!available) settle()
        else if (_ready && changed && animationsEnabled && visible && !jump.running && now - _lastAnimation >= minimumInterval) {
            _offset = value > _previous ? travel : -travel
            _zoom = jumpScale
            _lastAnimation = now
            jump.start()
        }
        _previous = value
    }
    onValueChanged: updateReading()
    onAnimationsEnabledChanged: if (!animationsEnabled) settle()
    onVisibleChanged: if (!visible) settle()
    Component.onCompleted: { _previous = value; _ready = true }
    ParallelAnimation {
        id: jump
        NumberAnimation { target: root; property: "_offset"; to: 0; duration: 230; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "_zoom"; to: 1; duration: 230; easing.type: Easing.OutCubic }
    }
}
