import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

Popup {
    id: root

    required property Item triggerItem
    property Item viewportItem: Overlay.overlay
    // Coordinates in the viewport, including any toolbar flickable offset.
    property point triggerPosition: Qt.point(triggerItem.x, triggerItem.y)
    property real viewportTop: ScreenTools.toolbarHeight
    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool requestedOpen: false
    property real revealProgress: 0
    signal pageRequested(string kind, int known)

    function toggle() { if (requestedOpen) close(); else open() }

    // CloseOnPressOutside would dismiss on the gear's press, before its click
    // toggles the drawer open again. Exclude the trigger from click-away close.
    parent: triggerItem
    x: (viewportItem ? viewportItem.width - width : 0) - triggerPosition.x
    y: viewportTop - triggerPosition.y
    width: Math.min(ScreenTools.defaultFontPixelWidth * 42,
                    viewportItem ? viewportItem.width * (ScreenTools.isMobile ? 0.88 : 0.34) : 520)
    height: viewportItem ? Math.max(0, viewportItem.height - viewportTop) : 600
    modal: false
    dim: false
    focus: true
    padding: 0
    opacity: revealProgress
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    onAboutToShow: requestedOpen = true
    onAboutToHide: requestedOpen = false

    // Only the visual layer moves. Current opacity is retained on reversal,
    // so a rapid second/third click can interrupt either transition smoothly.
    enter: Transition {
        NumberAnimation { target: root; property: "revealProgress"; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { target: root; property: "revealProgress"; to: 0; duration: 160; easing.type: Easing.OutCubic }
    }
    background: Rectangle { color: "transparent" }
    contentItem: HQFlightSetupMenu {
        vehicle: root.vehicle
        transform: Translate { x: (1 - root.revealProgress) * ScreenTools.defaultFontPixelWidth * 2 }
        onCloseRequested: root.close()
        onPageRequested: function(kind, known) {
            root.close()
            root.pageRequested(kind, known)
        }
    }
}
