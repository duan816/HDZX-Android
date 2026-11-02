import QtQuick

// The actual page loads immediately. Only its visual transform is animated.
Item {
    id: root
    required property var targetItem
    property var translation: null
    property bool animationsEnabled: true
    readonly property bool animating: arrival.running

    function settle() {
        arrival.stop()
        if (targetItem) targetItem.opacity = 1
        if (translation) translation.y = 0
    }
    function reveal() {
        if (!animationsEnabled || !targetItem || !targetItem.visible) { settle(); return }
        // Retarget an arrival in flight without jumping back to its first
        // frame. The new page is already selected and remains interactive.
        const opacity = animating ? targetItem.opacity : 0.82
        const offset = animating && translation ? translation.y : 6
        arrival.stop()
        fade.from = opacity
        slide.from = offset
        arrival.start()
    }
    onAnimationsEnabledChanged: if (!animationsEnabled) settle()
    Connections {
        target: root.targetItem
        function onVisibleChanged() { if (!root.targetItem.visible) root.settle() }
    }
    ParallelAnimation {
        id: arrival
        NumberAnimation { id: fade; target: root.targetItem; property: "opacity"; from: 0.82; to: 1; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { id: slide; target: root.translation; property: "y"; from: 6; to: 0; duration: 220; easing.type: Easing.OutCubic }
    }
}
