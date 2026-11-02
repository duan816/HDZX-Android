import QtQuick
import QGroundControl
import QGroundControl.Controls

// Shared geometry policy: direct manipulation follows the pointer, while
// button-driven changes animate. Resizing never changes the floating origin.
Item {
    id: motion
    objectName: "panelMotionPolicy"
    required property var targetItem
    readonly property bool docked: targetItem.dockSide !== undefined && targetItem.dockSide !== 0
    readonly property real tabWidth: Math.max(44, ScreenTools.minTouchPixels)
    property bool sizing: false
    property bool fullScreenTransition: false
    property bool placingAfterDrag: false
    property bool animateFullScreen: false
    readonly property int duration: 340
    readonly property var fluidCurve: [0.22, 1, 0.36, 1, 1, 1]
    property real pinnedX: 0
    property real pinnedY: 0
    readonly property bool animateGeometry: !placingAfterDrag && !docked && !targetItem.dragging && !targetItem.resizing
        && ((!targetItem.fullScreen && !fullScreenTransition) || (animateFullScreen && fullScreenTransition))
    // Heavy content uses the final open dimensions while the outer clip moves.
    // Animating the layout itself repaints canvases and rebuilds dial geometry.
    readonly property real contentWidth: targetItem.fullScreen && targetItem.expanded && targetItem.parent
        ? targetItem.parent.width : (targetItem.openWidth !== undefined ? targetItem.openWidth : targetItem.panelWidth)
    readonly property real contentHeight: targetItem.fullScreen && targetItem.expanded && targetItem.parent
        ? targetItem.parent.height : (targetItem.openHeight !== undefined ? targetItem.openHeight : targetItem.panelHeight)
    readonly property bool contentVisible: targetItem.expanded || conceal.running
    // Visibility changes affect only the visual layer. They never animate the
    // stored panel position, pointer manipulation, or the telemetry layout.
    OpacityAnimator {
        id: visibleReveal
        target: motion.targetItem
        from: 0.82
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }

    // -1/1: left/right, -2/2: top/bottom. The tab remains inside the
    // viewport even though the rest of the collapsed capsule is outside it.
    function tabRect(panel) {
        const horizontal = Math.abs(panel.dockSide) === 2
        const w = horizontal ? Math.min(panel.width, tabWidth * 1.8) : tabWidth
        const h = horizontal ? Math.min(panel.height, tabWidth) : panel.height
        return Qt.rect(panel.x + (panel.dockSide === -1 ? panel.width - w : 0),
                       panel.y + (panel.dockSide === -2 ? panel.height - h : 0), w, h)
    }
    function updateDockPosition() {
        const panel = targetItem
        if (!docked || !panel.parent || panel.dragging) return
        const rect = tabRect(panel)
        if (Math.abs(panel.dockSide) === 1) {
            panel.x = panel.dockSide === -1 ? -panel.width + rect.width : panel.parent.width - rect.width
            panel.y = Math.max(0, Math.min(panel.y, panel.parent.height - rect.height))
        } else {
            panel.x = Math.max(0, Math.min(panel.x, panel.parent.width - rect.width))
            panel.y = panel.dockSide === -2 ? -panel.height + rect.height : panel.parent.height - rect.height
        }
    }
    function separateTabs() {
        const panel = targetItem
        const horizontal = Math.abs(panel.dockSide) === 2
        const rect = tabRect(panel)
        const extent = horizontal ? rect.width : rect.height
        const limit = Math.max(0, (horizontal ? panel.parent.width : panel.parent.height) - extent)
        const wanted = horizontal ? rect.x : rect.y
        const occupied = []
        const candidates = [wanted, 0, limit]
        for (const other of panel.parent.children) {
            if (other === panel || !other.visible || other.dockSide !== panel.dockSide) continue
            const otherRect = tabRect(other)
            const start = horizontal ? otherRect.x : otherRect.y
            const end = start + (horizontal ? otherRect.width : otherRect.height)
            occupied.push({start: start, end: end})
            candidates.push(end + 4, start - extent - 4)
        }
        const available = candidates.map(function(value) { return Math.max(0, Math.min(value, limit)) })
            .filter(function(value) {
                return occupied.every(function(range) { return value + extent + 4 <= range.start || value >= range.end + 4 })
            }).sort(function(a, b) { return Math.abs(a - wanted) - Math.abs(b - wanted) })
        if (available.length) {
            if (horizontal) panel.x = available[0]
            else panel.y = available[0]
        }
    }
    function finishDockDrag() {
        const panel = targetItem
        if (!panel.parent || panel.fullScreen) return
        const rect = docked ? tabRect(panel) : Qt.rect(panel.x, panel.y, panel.width, panel.height)
        const edges = [{side: -1, distance: rect.x}, {side: 1, distance: panel.parent.width - rect.x - rect.width},
                       {side: -2, distance: rect.y}, {side: 2, distance: panel.parent.height - rect.y - rect.height}]
        edges.sort(function(a, b) { return a.distance - b.distance })
        // Only touching/overshooting the viewport docks; allow subpixel rounding, not a magnetic zone.
        const side = edges[0].distance <= 0.5 ? edges[0].side : 0
        placingAfterDrag = true
        panel.dockSide = side
        if (side) {
            panel.expanded = false
            panel.x = rect.x
            panel.y = rect.y
            updateDockPosition()
            separateTabs()
        } else {
            panel.x = Math.max(0, Math.min(rect.x, panel.parent.width - panel.width))
            panel.y = Math.max(0, Math.min(rect.y, panel.parent.height - panel.height))
        }
        placingAfterDrag = false
    }
    function restoreDocked() {
        const panel = targetItem
        if (!panel.parent) return
        const rect = tabRect(panel)
        panel.dockSide = 0
        panel.expanded = true
        const w = panel.openWidth !== undefined ? panel.openWidth : panel.panelWidth
        const h = panel.openHeight !== undefined ? panel.openHeight : panel.panelHeight
        const margin = panel.margin || 0
        panel.x = Math.max(margin, Math.min(rect.x, panel.parent.width - w - margin))
        panel.y = Math.max(margin, Math.min(rect.y, panel.parent.height - h - margin))
    }
    Rectangle {
        id: dockTab
        parent: motion.targetItem
        objectName: "panelDockTab"
        visible: motion.docked
        x: motion.targetItem.dockSide === -1 ? motion.targetItem.width - width : 0
        y: motion.targetItem.dockSide === -2 ? motion.targetItem.height - height : 0
        width: Math.abs(motion.targetItem.dockSide) === 2 ? Math.min(motion.targetItem.width, motion.tabWidth * 1.8) : motion.tabWidth
        height: Math.abs(motion.targetItem.dockSide) === 2 ? Math.min(motion.targetItem.height, motion.tabWidth) : motion.targetItem.height
        z: 300
        radius: Math.min(16, height / 2)
        color: "#F20C344B"
        border.color: "#58BACA"
        Text {
            anchors.centerIn: parent
            text: (motion.targetItem.dockTitle || "") + (Math.abs(motion.targetItem.dockSide) === 2
                ? (motion.targetItem.dockSide === -2 ? " ⌄" : " ⌃") : (motion.targetItem.dockSide === -1 ? "\n›" : "\n‹"))
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 13
            color: "#A8DBE8"
        }
        MouseArea {
            id: dockMouse
            objectName: "panelDockMouse"
            anchors.fill: parent
            preventStealing: true
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property point pressPoint
            property point grabOffset
            property bool moved: false
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: (motion.targetItem.dockTitle || "") + qsTr("：展开")
            Accessible.onPressAction: motion.restoreDocked()
            Keys.onReturnPressed: motion.restoreDocked()
            Keys.onSpacePressed: motion.restoreDocked()
            onPressed: mouse => {
                moved = false
                pressPoint = mapToItem(motion.targetItem.parent, mouse.x, mouse.y)
                grabOffset = Qt.point(mouse.x, mouse.y)
            }
            onPositionChanged: mouse => {
                if (!pressed || !motion.targetItem.parent) return
                const position = mapToItem(motion.targetItem.parent, mouse.x, mouse.y)
                if (!moved && Math.hypot(position.x - pressPoint.x, position.y - pressPoint.y) < Qt.styleHints.startDragDistance) return
                moved = true
                motion.targetItem.dragging = true
                const x = Math.max(0, Math.min(position.x - grabOffset.x, motion.targetItem.parent.width - dockTab.width))
                const y = Math.max(0, Math.min(position.y - grabOffset.y, motion.targetItem.parent.height - dockTab.height))
                motion.targetItem.x = x - dockTab.x
                motion.targetItem.y = y - dockTab.y
            }
            onReleased: {
                motion.targetItem.dragging = false
                if (moved) motion.finishDockDrag()
            }
            onCanceled: {
                motion.targetItem.dragging = false
                motion.updateDockPosition()
            }
            onClicked: if (!moved) motion.restoreDocked()
        }
        HQButtonRipple { control: dockMouse }
    }
    Connections {
        target: motion.targetItem.parent
        function onWidthChanged() { if (motion.docked) motion.updateDockPosition() }
        function onHeightChanged() { if (motion.docked) motion.updateDockPosition() }
    }

    function pinPosition() {
        // Replace initial right/centre placement bindings with the actual
        // position before changing dimensions. Otherwise they move the panel.
        pinnedX = targetItem.x
        pinnedY = targetItem.y
        targetItem.x = Qt.binding(function() { return motion.pinnedX })
        targetItem.y = Qt.binding(function() { return motion.pinnedY })
    }

    function beginResize() {
        settling.stop()
        sizing = true
        targetItem.resizing = true
        pinPosition()
    }

    function boundedFactor(requested) {
        const panel = targetItem
        const current = panel.sizeFactor
        const openWidth = panel.openWidth !== undefined ? panel.openWidth : panel.panelWidth
        const openHeight = panel.openHeight !== undefined ? panel.openHeight : panel.panelHeight
        const margin = panel.margin || 0
        let upper = panel.scaleMax
        if (panel.parent && requested > current && openWidth > 0 && openHeight > 0) {
            // At the viewport edge stop growing, rather than relocating the
            // panel or hiding the resize grip beyond the screen.
            upper = Math.min(upper, current * Math.max(0, panel.parent.width - panel.x - margin) / openWidth,
                             current * Math.max(0, panel.parent.height - panel.y - margin) / openHeight)
            upper = Math.max(current, upper)
        }
        return Math.max(panel.scaleMin, Math.min(upper, requested))
    }

    function endResize() {
        targetItem.resizing = false
        settling.restart()
    }

    function adjustSize(delta) {
        if (targetItem.fullScreen) return
        beginResize()
        // Pin without a positional animation; the dimensions themselves are
        // animated for +/- but never lag behind a dragged edge.
        targetItem.resizing = false
        targetItem.sizeFactor = boundedFactor(Number((targetItem.sizeFactor + delta).toFixed(2)))
        settling.restart()
    }

    Timer { id: settling; interval: 340; onTriggered: motion.sizing = false }
    Timer { id: conceal; interval: motion.duration + 30 }
    Timer { id: fullScreenSettling; interval: 340; onTriggered: motion.fullScreenTransition = false }
    OpacityAnimator { id: fullScreenReveal; target: motion.targetItem; from: 0.78; to: 1; duration: 190; easing.type: Easing.OutCubic }
    Connections {
        target: motion.targetItem
        function onVisibleChanged() {
            visibleReveal.stop()
            fullScreenReveal.stop()
            motion.targetItem.opacity = 1
            if (motion.targetItem.visible) visibleReveal.start()
            else {
                conceal.stop()
                settling.stop()
                fullScreenSettling.stop()
                motion.sizing = false
                motion.fullScreenTransition = false
            }
        }
        function onWidthChanged() { if (motion.docked) motion.updateDockPosition() }
        function onHeightChanged() { if (motion.docked) motion.updateDockPosition() }
        function onExpandedChanged() {
            const panel = motion.targetItem
            if (panel.expanded) conceal.stop()
            else conceal.restart()
            if (motion.docked) { motion.updateDockPosition(); return }
            if (panel.fullScreen || motion.fullScreenTransition || !panel.parent) return
            motion.pinPosition()
            if (panel.expanded) {
                const width = panel.openWidth !== undefined ? panel.openWidth : panel.panelWidth
                const height = panel.openHeight !== undefined ? panel.openHeight : panel.panelHeight
                const margin = panel.margin || 0
                panel.x = Math.max(margin, Math.min(panel.x, panel.parent.width - width - margin))
                panel.y = Math.max(margin, Math.min(panel.y, panel.parent.height - height - margin))
            }
        }
        function onFullScreenChanged() {
            visibleReveal.stop()
            motion.fullScreenTransition = true
            fullScreenSettling.restart()
            fullScreenReveal.restart()
        }
    }
}
