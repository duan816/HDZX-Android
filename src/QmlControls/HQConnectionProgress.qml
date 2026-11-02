import QtQuick
import QGroundControl

Item {
    id: root
    property real progress: NaN
    property bool connected: false
    property bool communicationLost: false
    property bool animationsEnabled: true
    property bool indeterminate: false
    property var sourceToken: null
    property color accent: QGroundControl.globalPalette.colorGreen
    property color trackColor: QGroundControl.globalPalette.groupBorder
    property real displayedProgress: 0
    readonly property bool valid: connected && isFinite(progress) && progress >= 0 && progress <= 1
    readonly property real reportedProgress: valid ? progress : 0
    readonly property real renderedProgress: valid ? Math.min(reportedProgress, Math.max(0, displayedProgress)) : 0
    readonly property string percentageText: valid ? Math.floor(reportedProgress * 100) + "%" : "--"
    readonly property bool animating: advance.running
    readonly property bool pulsing: fillPulse.running || waitingPulse.running
    readonly property bool indeterminateRunning: waitingTravel.running
    readonly property bool shimmerRunning: shimmerTravel.running
    readonly property bool _canAnimate: visible && connected && !communicationLost && animationsEnabled
    readonly property bool _pulseFill: _canAnimate && valid && !indeterminate
                                      && reportedProgress > 0 && reportedProgress < 1
    implicitHeight: 3

    function snap() {
        advance.stop()
        displayedProgress = reportedProgress
    }
    function updateProgress() {
        advance.stop()
        if (!valid || communicationLost || !animationsEnabled || !visible || reportedProgress <= displayedProgress) {
            snap()
            return
        }
        // The fill can only approach already reported progress, never lead it.
        advance.from = displayedProgress
        advance.to = reportedProgress
        advance.start()
    }
    onReportedProgressChanged: updateProgress()
    onCommunicationLostChanged: snap()
    onSourceTokenChanged: snap()
    onAnimationsEnabledChanged: if (!animationsEnabled) snap()
    onVisibleChanged: if (!visible) snap()
    Component.onCompleted: snap()

    Rectangle {
        objectName: "connectionProgressTrack"
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
        opacity: 0.45
    }
    Rectangle {
        id: fill
        objectName: "connectionProgressFill"
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.width * root.renderedProgress
        radius: height / 2
        clip: true
        visible: !root.indeterminate && root.renderedProgress > 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.darker(root.accent, 1.3) }
            GradientStop { position: 1; color: Qt.lighter(root.accent, 1.25) }
        }
        Rectangle {
            id: shimmer
            width: Math.min(90, Math.max(16, fill.width * 0.25))
            height: parent.height
            visible: root._pulseFill
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#00ffffff" }
                GradientStop { position: 0.5; color: "#aaffffff" }
                GradientStop { position: 1; color: "#00ffffff" }
            }
        }
    }
    Rectangle {
        id: waitingSegment
        objectName: "connectionWaitingSegment"
        width: root.width * 0.22
        height: root.height
        radius: height / 2
        color: root.accent
        visible: root.indeterminate && root.connected
    }
    NumberAnimation {
        id: shimmerTravel
        target: shimmer
        property: "x"
        from: -shimmer.width
        to: fill.width
        duration: 1800
        loops: Animation.Infinite
        running: root._pulseFill
    }
    NumberAnimation {
        id: advance
        target: root
        property: "displayedProgress"
        duration: 140
        easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        id: fillPulse
        running: root._pulseFill
        loops: Animation.Infinite
        onRunningChanged: if (!running) fill.opacity = 1
        NumberAnimation { target: fill; property: "opacity"; from: 1; to: 0.58; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { target: fill; property: "opacity"; from: 0.58; to: 1; duration: 700; easing.type: Easing.InOutSine }
    }
    SequentialAnimation {
        id: waitingPulse
        running: root._canAnimate && root.indeterminate
        loops: Animation.Infinite
        onRunningChanged: if (!running) waitingSegment.opacity = 1
        NumberAnimation { target: waitingSegment; property: "opacity"; from: 1; to: 0.58; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { target: waitingSegment; property: "opacity"; from: 0.58; to: 1; duration: 700; easing.type: Easing.InOutSine }
    }
    NumberAnimation {
        id: waitingTravel
        target: waitingSegment
        property: "x"
        from: 0
        to: root.width - waitingSegment.width
        duration: 1500
        easing.type: Easing.InOutSine
        loops: Animation.Infinite
        running: root._canAnimate && root.indeterminate
        onRunningChanged: if (!running) waitingSegment.x = 0
    }
}
