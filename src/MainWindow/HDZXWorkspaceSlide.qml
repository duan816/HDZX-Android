import QtQuick

// Navigation commits synchronously; this controller never gates page loading or input.
Item {
    id: root

    property bool animationsEnabled: true
    property int motionMode: 0 // 0: crossfade, 1: demonstration slide, 2: direct
    readonly property int duration: motionMode === 1 ? 280 : 200
    property real progress: 1
    property Item incoming: null
    property real incomingOffset: 0
    property Item outgoing: null
    property real outgoingOffset: 0
    property bool restoreOutgoingVisible: false
    readonly property bool running: motion.running

    signal settled

    function offsetFor(item) {
        if (motionMode !== 1) return 0;
        return item === incoming ? incomingOffset : item === outgoing ? outgoingOffset : 0;
    }

    function opacityFor(item) {
        if (motionMode !== 0) return 1;
        return item === incoming ? progress : item === outgoing ? 1 - progress : 1;
    }

    function settle() {
        motion.stop();
        if (outgoing && outgoing !== incoming)
            outgoing.visible = restoreOutgoingVisible;
        if (incoming)
            incoming.visible = true;
        outgoingOffset = 0;
        incomingOffset = 0;
        progress = 1;
        outgoing = null;
        incoming = null;
        settled();
    }

    function slide(previous, next, forward, finalPreviousVisible) {
        // The caller settles before changing pages, so visibility here is the final state.
        if (!animationsEnabled || motionMode === 2 || !previous || !next || previous === next) {
            settle();
            if (previous && previous !== next && finalPreviousVisible !== undefined)
                previous.visible = finalPreviousVisible;
            if (next) next.visible = true;
            return;
        }
        outgoing = previous;
        incoming = next;
        restoreOutgoingVisible = finalPreviousVisible === undefined ? previous.visible : finalPreviousVisible;
        const travel = Math.max(1, next.width);
        outgoingMotion.to = motionMode === 1 ? (forward ? travel : -travel) : 0;
        outgoingOffset = 0;
        incomingOffset = motionMode === 1 ? (forward ? -travel : travel) : 0;
        progress = 0;
        previous.visible = true;
        next.visible = true;
        motion.start();
    }

    onAnimationsEnabledChanged: if (!animationsEnabled)
        settle()
    onMotionModeChanged: settle()

    ParallelAnimation {
        id: motion

        onFinished: root.settle()

        NumberAnimation {
            duration: root.duration
            easing.type: Easing.InOutQuad
            property: "progress"
            target: root
            from: 0
            to: 1
        }

        NumberAnimation {
            id: outgoingMotion

            duration: root.duration
            easing.type: Easing.InOutQuad
            property: "outgoingOffset"
            target: root
        }

        NumberAnimation {
            duration: root.duration
            easing.type: Easing.InOutQuad
            property: "incomingOffset"
            target: root
            to: 0
        }
    }
}
