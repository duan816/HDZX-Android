pragma ComponentBehavior: Bound
import QtQuick
import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    required property var dashboard
    required property var descriptor
    readonly property string instrumentKey: descriptor.key
    readonly property var placement: dashboard.floatingEntry(instrumentKey)
    readonly property real reading: dashboard.readingFor(instrumentKey)
    readonly property real maximum: dashboard.maximumFor(descriptor)
    readonly property string unit: dashboard.unitFor(descriptor)
    readonly property bool available: isFinite(reading)
    readonly property bool ring: instrumentKey === "battery" || instrumentKey === "rcRSSI"
    readonly property bool linear: instrumentKey === "altitudeRelative" || instrumentKey === "climbRate"
    readonly property bool angular: dashboard.isSpeed(instrumentKey) && dashboard.activeTheme.kind === "digital"
    property bool dragging: false
    property bool controlsVisible: false
    property real sizeFactor: placement ? placement.size : 1
    visible: dashboard.visible && !!placement
    width: Math.min(parent ? Math.min(parent.width, parent.height) : 260, 240 * sizeFactor)
    height: width
    z: QGroundControl.zOrderTopMost + (dragging ? 90 : 25)
    objectName: "detachedInstrument-" + instrumentKey
    Accessible.name: descriptor.title
    Accessible.description: qsTr("拖动可移动；打开飞行仪表盘后拖回即可收纳。")

    function clampPosition() {
        if (!parent) return
        x = Math.max(0, Math.min(x, parent.width - width))
        y = Math.max(0, Math.min(y, parent.height - height))
    }
    function restorePosition() {
        if (!parent || !placement || dragging) return
        x = placement.x * Math.max(0, parent.width - width)
        y = placement.y * Math.max(0, parent.height - height)
        clampPosition()
    }
    function savePosition() {
        if (!parent || !placement) return
        clampPosition()
        dashboard.saveFloating(instrumentKey, {
            x: parent.width > width ? x / (parent.width - width) : 0,
            y: parent.height > height ? y / (parent.height - height) : 0,
            size: sizeFactor
        })
    }
    function moveCenter(point) {
        dragging = true
        x = point.x - width / 2; y = point.y - height / 2
        clampPosition()
    }
    function finishDrag(point, canceled) {
        dragging = false
        dashboard.floatingDragKey = ""
        if (canceled) restorePosition()
        else if (dashboard.acceptsInstrumentAt(point)) dashboard.dockInstrument(instrumentKey)
        else savePosition()
    }
    function resizeBy(delta) {
        sizeFactor = Math.max(0.65, Math.min(1.8, sizeFactor + delta))
        savePosition()
    }
    onPlacementChanged: Qt.callLater(restorePosition)
    onVisibleChanged: if (visible) Qt.callLater(restorePosition)
    Component.onCompleted: Qt.callLater(restorePosition)
    Connections {
        target: root.parent
        function onWidthChanged() { root.restorePosition() }
        function onHeightChanged() { root.restorePosition() }
    }
    // Only instrument pixels are painted; no enclosing card or title bar.
    Loader {
        anchors.fill: parent
        active: root.visible
        sourceComponent: Component {
            Item {
                HQFlightDial {
                    anchors.fill: parent; visible: !root.ring && !root.linear && !root.angular
                    value: root.reading; minimum: root.descriptor.min; maximum: root.maximum
                    majorIntervals: root.dashboard.isSpeed(root.instrumentKey) ? root.dashboard.speedIntervalsFor(root.instrumentKey) : 6
                    compass: root.instrumentKey === "heading"
                    valueText: root.available ? root.reading.toFixed(compass ? 0 : 1) : "--"
                    unit: root.unit
                    skin: root.dashboard.activeTheme.skin; accent: root.dashboard.activeTheme.accent
                    badge: root.dashboard.isSpeed(root.instrumentKey) ? root.dashboard.activeTheme.name : ""
                    modeToken: root.dashboard.modeTokenFor(root.instrumentKey)
                    animationsEnabled: root.dashboard.modeAnimationsEnabled
                }
                HQLinearInstrument { anchors.fill: parent; visible: root.linear; value: root.reading; verticalSpeed: root.instrumentKey === "climbRate"; accent: root.descriptor.color; animationsEnabled: root.dashboard.modeAnimationsEnabled }
                HQAngularSpeed { anchors.fill: parent; visible: root.angular; value: root.reading; maximum: root.maximum; unit: root.unit; accent: root.dashboard.activeTheme.accent; theme: root.dashboard.activeTheme }
                HQCircularGauge {
                    anchors.fill: parent; visible: root.ring; instrumentStyle: false
                    fraction: root.available ? root.reading / 100 : NaN
                    valueText: root.available ? root.reading.toFixed(0) : "--"
                    caption: "%"; centerSymbol: root.instrumentKey === "battery" ? "▰" : ""
                    critical: root.available && root.reading <= 20
                    accentColor: critical ? "#FF705E" : root.descriptor.color
                }
            }
        }
    }
    MouseArea {
        id: dragArea
        objectName: "detachedDrag-" + root.instrumentKey
        anchors.fill: parent
        hoverEnabled: !ScreenTools.isMobile
        preventStealing: true
        drag.target: root
        drag.minimumX: 0; drag.minimumY: 0
        drag.maximumX: root.parent ? Math.max(0, root.parent.width - root.width) : 0
        drag.maximumY: root.parent ? Math.max(0, root.parent.height - root.height) : 0
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: { root.dragging = true; root.dashboard.floatingDragKey = root.instrumentKey }
        onReleased: function(mouse) { root.finishDrag(mapToItem(root.parent, mouse.x, mouse.y), false) }
        onCanceled: root.finishDrag(Qt.point(0, 0), true)
        onPressAndHold: { root.controlsVisible = true; controlsTimeout.restart() }
    }
    HoverHandler { id: instrumentHover }
    Timer { id: controlsTimeout; interval: 5000; onTriggered: root.controlsVisible = false }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        visible: (instrumentHover.hovered || root.controlsVisible) && !root.dragging
        opacity: 0.85; spacing: 3
        QGCButton { width: 44; height: 44; leftPadding: 4; rightPadding: 4; text: "−"; onClicked: root.resizeBy(-0.1) }
        QGCButton { width: 56; height: 44; leftPadding: 4; rightPadding: 4; pointSize: ScreenTools.smallFontPointSize; text: qsTr("收回"); onClicked: root.dashboard.dockInstrument(root.instrumentKey) }
        QGCButton { width: 44; height: 44; leftPadding: 4; rightPadding: 4; text: "+"; onClicked: root.resizeBy(0.1) }
    }
}
