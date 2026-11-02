import QtQuick
import QGroundControl
import QGroundControl.Controls

// Keep the original mouse grab while its dial moves to the floating layer.
// Touch starts with a long press so the instrument list can still scroll.
MouseArea {
    id: area
    property var dashboard: null
    required property string instrumentKey
    property real startX: 0
    property real startY: 0
    property bool ready: !ScreenTools.isMobile
    property bool moving: false
    enabled: !!dashboard
    preventStealing: ready
    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    onPressed: function(mouse) {
        startX = mouse.x
        startY = mouse.y
        ready = !ScreenTools.isMobile
        moving = false
    }
    onPressAndHold: ready = true
    onPositionChanged: function(mouse) {
        if (!pressed || !ready) return
        if (!moving && Math.hypot(mouse.x - startX, mouse.y - startY) <= Qt.styleHints.startDragDistance) return
        moving = true
        dashboard.moveInstrumentFromCard(instrumentKey, area, mouse.x, mouse.y)
    }
    onReleased: function(mouse) {
        dashboard.finishInstrumentFromCard(instrumentKey, area, mouse.x, mouse.y, false)
        moving = false
    }
    onCanceled: {
        if (dashboard) dashboard.finishInstrumentFromCard(instrumentKey, area, startX, startY, true)
        moving = false
    }
}
