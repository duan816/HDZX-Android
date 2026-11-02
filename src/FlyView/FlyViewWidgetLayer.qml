import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QtLocation
import QtPositioning
import QtQuick.Window
import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.Viewer3D

// This is the ui overlay layer for the widgets/tools for Fly View
Item {
    id: _root

    property var    parentToolInsets
    property var    totalToolInsets:        _totalToolInsets
    property var    mapControl
    property var    viewer3DCameraController

    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property var    _planMasterController:  globals.planMasterControllerFlyView
    property var    _missionController:     _planMasterController.missionController
    property var    _geoFenceController:    _planMasterController.geoFenceController
    property var    _rallyPointController:  _planMasterController.rallyPointController
    property var    _guidedController:      globals.guidedControllerFlyView
    property real   _margins:               ScreenTools.defaultFontPixelWidth / 2
    property real   _toolsMargin:           ScreenTools.defaultFontPixelWidth * 0.75
    property rect   _centerViewport:        Qt.rect(0, 0, width, height)
    property real   _rightPanelWidth:       ScreenTools.defaultFontPixelWidth * 30
    property real   _layoutMargin:          ScreenTools.defaultFontPixelWidth * 0.75
    property real   _layoutSpacing:         ScreenTools.defaultFontPixelWidth
    property bool   _showSingleVehicleUI:   true
    property bool   _tuningVisible:         true
    property bool   _hudVisible:            true
    property bool   _pidVisible:            true
    property bool   _dashboardVisible:      true
    property bool   _toolStripCompact:      false
    property bool   _toolStripTransparent:  false
    readonly property real classicHudLeftInset: hqHud.visible && hqHud.expanded && hqHud.splitLayout && !hqHud.fullScreen ? hqHud.width + _toolsMargin : 0
    readonly property real _mobileLeftToolX: toolStrip.x + toolStrip.width + _toolsMargin
    readonly property real _mobileDockRowHeight: Math.max(ScreenTools.mobileTouchTarget, ScreenTools.defaultFontPixelHeight * 2.8) + _toolsMargin
    signal hudStatusRequested()

    readonly property string _toolSettingsPrefix: "HQFlyToolWarehouse/"

    function showVehicleConfigSidebar(kind, knownComponent) {
        vehicleConfigSidebar.openPage(kind, knownComponent)
    }

    function setToolVisible(key, visible) {
        switch (key) {
        case "tuning": _tuningVisible = visible; break
        case "hud": _hudVisible = visible; break
        case "pid": _pidVisible = visible; break
        case "dashboard": _dashboardVisible = visible; break
        default: return
        }
        QGroundControl.saveBoolGlobalSetting(_toolSettingsPrefix + key, visible)
    }

    function maybeStoreDraggedTool(item, key) {
        if (!item || item.dragging || !item.visible)
            return
        var p = item.mapToItem(_root, item.width / 2, item.height / 2)
        var dockLeft = toolWarehouse.x - ScreenTools.defaultFontPixelWidth * 2
        var dockBottom = toolWarehouse.y + toolWarehouse.height + ScreenTools.defaultFontPixelHeight * 2
        if (p.x >= dockLeft && p.x <= toolWarehouse.x + toolWarehouse.width + ScreenTools.defaultFontPixelWidth * 2
                && p.y >= toolWarehouse.y - ScreenTools.defaultFontPixelHeight * 2 && p.y <= dockBottom) {
            setToolVisible(key, false)
            toolWarehouse.acceptingDrop = false
            toolWarehouse.expanded = true
        }
    }

    Component.onCompleted: {
        _tuningVisible = QGroundControl.loadBoolGlobalSetting(_toolSettingsPrefix + "tuning", !ScreenTools.isMobile)
        _hudVisible = QGroundControl.loadBoolGlobalSetting(_toolSettingsPrefix + "hud", true)
        _pidVisible = QGroundControl.loadBoolGlobalSetting(_toolSettingsPrefix + "pid", true)
        _dashboardVisible = QGroundControl.loadBoolGlobalSetting(_toolSettingsPrefix + "dashboard", true)
        _toolStripCompact = QGroundControl.loadBoolGlobalSetting(_toolSettingsPrefix + "toolStripCompact", ScreenTools.isMobile)
        _toolStripTransparent = QGroundControl.loadBoolGlobalSetting(_toolSettingsPrefix + "toolStripTransparent", false)
    }

    HQVehicleConfigSidebar {
        id: vehicleConfigSidebar
        parent: _root
        z: QGroundControl.zOrderTopMost + 100
    }

    QGCToolInsets {
        id:                     _totalToolInsets
        leftEdgeTopInset:       Math.max(toolStrip.leftEdgeTopInset, _root.classicHudLeftInset)
        leftEdgeCenterInset:    Math.max(toolStrip.leftEdgeCenterInset, _root.classicHudLeftInset)
        leftEdgeBottomInset:    Math.max(_root.classicHudLeftInset, virtualJoystickMultiTouch.visible ? virtualJoystickMultiTouch.leftEdgeBottomInset : parentToolInsets.leftEdgeBottomInset)
        rightEdgeTopInset:      topRightPanel.rightEdgeTopInset
        rightEdgeCenterInset:   topRightPanel.rightEdgeCenterInset
        rightEdgeBottomInset:   bottomRightRowLayout.rightEdgeBottomInset
        topEdgeLeftInset:       toolStrip.topEdgeLeftInset
        topEdgeCenterInset:     mapScale.topEdgeCenterInset
        topEdgeRightInset:      topRightPanel.topEdgeRightInset
        bottomEdgeLeftInset:    virtualJoystickMultiTouch.visible ? virtualJoystickMultiTouch.bottomEdgeLeftInset : parentToolInsets.bottomEdgeLeftInset
        bottomEdgeCenterInset:  bottomRightRowLayout.bottomEdgeCenterInset
        bottomEdgeRightInset:   virtualJoystickMultiTouch.visible ? virtualJoystickMultiTouch.bottomEdgeRightInset : bottomRightRowLayout.bottomEdgeRightInset
    }

    FlyViewTopRightPanel {
        id:                     topRightPanel
        anchors.top:            parent.top
        anchors.right:          parent.right
        maximumHeight:          parent.height - (bottomRightRowLayout.height + _margins * 4)

        property real topEdgeRightInset:    height + _layoutMargin
        property real rightEdgeTopInset:    width + _layoutMargin
        property real rightEdgeCenterInset: rightEdgeTopInset
    }

    FlyViewTopRightColumnLayout {
        id:                 topRightColumnLayout
        anchors.top:        parent.top
        anchors.right:      parent.right
        spacing:            _layoutSpacing
        visible:           !topRightPanel.visible

        property real topEdgeRightInset:    childrenRect.height + _layoutMargin
        property real rightEdgeTopInset:    width + _layoutMargin
        property real rightEdgeCenterInset: rightEdgeTopInset
    }

    FlyViewBottomRightRowLayout {
        id:                 bottomRightRowLayout
        anchors.bottom:     parent.bottom
        anchors.right:      parent.right
        spacing:            _layoutSpacing
        visible:            !(hqHud.visible && hqHud.expanded)

        property real bottomEdgeRightInset:     visible ? height + _layoutMargin : 0
        property real bottomEdgeCenterInset:    bottomEdgeRightInset
        property real rightEdgeBottomInset:     visible ? width + _layoutMargin : 0
    }

    FlyViewMissionCompleteDialog {
        missionController:      _missionController
        geoFenceController:     _geoFenceController
        rallyPointController:   _rallyPointController
    }

    // Prevent the map's PinchHandler from stealing touch grabs from the joystick pads (issue #13450)
    Binding {
        target:   mapControl
        property: "pinchZoomDisabledByVirtualJoysticks"
        value:    virtualJoystickMultiTouch.visible && virtualJoystickMultiTouch.item && virtualJoystickMultiTouch.item.stickActive
    }

    //-- Virtual Joystick
    Loader {
        id:                         virtualJoystickMultiTouch
        z:                          QGroundControl.zOrderTopMost + 1
        anchors.right:              parent.right
        anchors.rightMargin:        anchors.leftMargin
        height:                     Math.min(parent.height * 0.25, ScreenTools.defaultFontPixelWidth * 16)
        visible:                    _virtualJoystickEnabled && !QGroundControl.videoManager.fullScreen && !(_activeVehicle ? _activeVehicle.usingHighLatencyLink : false)
        anchors.bottom:             parent.bottom
        anchors.bottomMargin:       bottomLoaderMargin
        anchors.left:               parent.left
        anchors.leftMargin:         ( y > toolStrip.y + toolStrip.height ? toolStrip.width / 2 : toolStrip.width * 1.05 + toolStrip.x)
        source:                     "qrc:/qml/QGroundControl/FlyView/VirtualJoystick.qml"
        active:                     _virtualJoystickEnabled && !(_activeVehicle ? _activeVehicle.usingHighLatencyLink : false)

        property real bottomEdgeLeftInset:     parent.height-y
        property bool autoCenterThrottle:      QGroundControl.settingsManager.appSettings.virtualJoystickAutoCenterThrottle.rawValue
        property bool leftHandedMode:          QGroundControl.settingsManager.appSettings.virtualJoystickLeftHandedMode.rawValue
        property bool _virtualJoystickEnabled: QGroundControl.settingsManager.appSettings.virtualJoystick.rawValue
        property real bottomEdgeRightInset:    parent.height-y
        property var  _pipViewMargin:          _pipView.visible ? parentToolInsets.bottomEdgeLeftInset + ScreenTools.defaultFontPixelHeight * 2 :
                                               bottomRightRowLayout.height + ScreenTools.defaultFontPixelHeight * 1.5

        property var  bottomLoaderMargin:      _pipViewMargin >= parent.height / 2 ? parent.height / 2 : _pipViewMargin

        // Width is difficult to access directly hence this hack which may not work in all circumstances
        property real leftEdgeBottomInset:  visible ? bottomEdgeLeftInset + width/18 - ScreenTools.defaultFontPixelHeight*2 : 0
        property real rightEdgeBottomInset: visible ? bottomEdgeRightInset + width/18 - ScreenTools.defaultFontPixelHeight*2 : 0
        property real rootWidth:            _root.width
        property var  itemX:                virtualJoystickMultiTouch.x   // real X on screen

        onRootWidthChanged: virtualJoystickMultiTouch.status == Loader.Ready && visible ? virtualJoystickMultiTouch.item.uiTotalWidth = rootWidth : undefined
        onItemXChanged:     virtualJoystickMultiTouch.status == Loader.Ready && visible ? virtualJoystickMultiTouch.item.uiRealX = itemX : undefined

        //Loader status logic
        onLoaded: {
            if (virtualJoystickMultiTouch.visible) {
                virtualJoystickMultiTouch.item.calibration = true
                virtualJoystickMultiTouch.item.uiTotalWidth = rootWidth
                virtualJoystickMultiTouch.item.uiRealX = itemX
            } else {
                virtualJoystickMultiTouch.item.calibration = false
            }
        }
    }

    FlyViewToolStrip {
        id:                     toolStrip
        anchors.left:           parent.left
        anchors.leftMargin:     _root.classicHudLeftInset
        anchors.top:            parent.top
        z:                      QGroundControl.zOrderWidgets
        maxHeight:              parent.height - y - parentToolInsets.bottomEdgeLeftInset - _toolsMargin
        compactMode:            _toolStripCompact
        transparentBackground: _toolStripTransparent

        onRebootVehicleRequested: {
            if (!_activeVehicle || _activeVehicle.armed || _activeVehicle.flying) {
                QGroundControl.showMessageDialog(_root, qsTr("无法重启飞控"),
                    qsTr("仅允许在飞行器已连接、未解锁且未飞行时重启飞控。"), Dialog.Ok)
                return
            }
            const targetVehicle = _activeVehicle
            QGroundControl.showMessageDialog(_root, qsTr("确认重启飞控"),
                qsTr("确定要重启 %1 号飞控吗？只操作当前选中的设备，重启期间连接暂时中断。请勿在飞行中执行。").arg(targetVehicle.id),
                Dialog.Cancel | Dialog.Ok,
                function() {
                    if (_activeVehicle && !_activeVehicle.armed && !_activeVehicle.flying)
                        if (targetVehicle && targetVehicle === QGroundControl.multiVehicleManager.activeVehicle && !targetVehicle.armed && !targetVehicle.flying) targetVehicle.rebootVehicle()
                })
        }
        visible:                !QGroundControl.videoManager.fullScreen

        onDisplayPreFlightChecklist: {
            if (!preFlightChecklistLoader.active) {
                preFlightChecklistLoader.active = true
            }
            preFlightChecklistLoader.item.open()
        }

        property real topEdgeLeftInset:     visible ? y + height : 0
        property real leftEdgeTopInset:     visible ? x + width : 0
        property real leftEdgeCenterInset:  leftEdgeTopInset
    }

    QGCButton {
        id: toolStripAppearanceButton
        anchors.left: toolStrip.right
        anchors.top: toolStrip.top
        anchors.margins: _margins * 0.6
        z: QGroundControl.zOrderWidgets + 1
        width: Math.max(ScreenTools.mobileTouchTarget, ScreenTools.defaultFontPixelHeight * 2.0)
        height: width
        text: "◐"
        visible: toolStrip.visible
        onClicked: toolStripAppearancePopup.open()
    }

    Popup {
        id: toolStripAppearancePopup
        x: Math.max(_margins, Math.min(toolStripAppearanceButton.x + toolStripAppearanceButton.width + _margins, _root.width - width - _margins))
        y: Math.max(_margins, Math.min(toolStripAppearanceButton.y, _root.height - height - _margins))
        width: Math.min(ScreenTools.defaultFontPixelWidth * 27, _root.width * 0.72)
        padding: _margins * 1.4
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 9
            color: "#F20A243A"
            border.color: "#46C8D8"
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: _margins
            QGCLabel { text: qsTr("飞行操作栏显示"); color: "white"; font.weight: Font.Bold }
            Switch {
                text: qsTr("紧凑尺寸")
                checked: _toolStripCompact
                onToggled: {
                    _toolStripCompact = checked
                    QGroundControl.saveBoolGlobalSetting(_toolSettingsPrefix + "toolStripCompact", checked)
                }
            }
            Switch {
                text: qsTr("透明背景（仅显示按钮）")
                checked: _toolStripTransparent
                onToggled: {
                    _toolStripTransparent = checked
                    QGroundControl.saveBoolGlobalSetting(_toolSettingsPrefix + "toolStripTransparent", checked)
                }
            }
            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("设置会自动保存，电脑端和手机端分别使用各自的显示比例。")
                color: "#9FC3D4"
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }
    }

    VehicleWarnings {
        anchors.centerIn:   parent
        z:                  QGroundControl.zOrderTopMost
    }

    MapScale {
        id:                 mapScale
        anchors.left:       toolStripAppearanceButton.right
        anchors.leftMargin: _toolsMargin
        anchors.top:        parent.top
        mapControl:         _mapControl
        autoHide:           true
        visible:            !ScreenTools.isTinyScreen && QGroundControl.corePlugin.options.flyView.showMapScale && QGCViewer3DManager.displayMode !== QGCViewer3DManager.View3D && mapControl.pipState.state === mapControl.pipState.fullState

        property real topEdgeCenterInset: visible ? y + height : 0
    }

    Viewer3DScaleBar {
        objectName:         "viewer3DScaleBar"
        anchors.left:       toolStripAppearanceButton.right
        anchors.leftMargin: _toolsMargin
        anchors.top:        parent.top
        controller:         _root.viewer3DCameraController
        autoHide:           true
        visible:            !ScreenTools.isTinyScreen && QGroundControl.corePlugin.options.flyView.showMapScale && QGCViewer3DManager.displayMode === QGCViewer3DManager.View3D && !!_root.viewer3DCameraController
    }

    Loader {
        id: preFlightChecklistLoader
        sourceComponent: preFlightChecklistPopup
        active: false
    }

    Component {
        id: preFlightChecklistPopup
        FlyViewPreFlightChecklistPopup {
        }
    }







    HQExtendedTuning {
        id: hqExtendedTuning
        visible: _tuningVisible
        x: _toolsMargin
        y: Math.max(_toolsMargin, _root.height * 0.13)
        HQFullScreenControl { targetItem: hqExtendedTuning }
    }

    HQHud {
        id: hqHud
        // Release Fact bindings in phase 1, before the vehicle is destroyed
        // after the removal notifications have returned to the event loop.
        vehicle: QGroundControl.multiVehicleManager.activeVehicleAvailable ? _root._activeVehicle : null
        guidedController: _root._guidedController
        visible: _hudVisible
        onCloseRequested: _root.setToolVisible("hud", false)
        onStatusRequested: _root.hudStatusRequested()
        onPreflightRequested: {
            if (!preFlightChecklistLoader.active) preFlightChecklistLoader.active = true
            if (preFlightChecklistLoader.item) preFlightChecklistLoader.item.open()
        }
        onSetupRequested: kind => _root.showVehicleConfigSidebar(kind)
        onLogsRequested: mainWindow.showAnalyzeTool()
        onActionRequested: action => {
            const allowed = ["Arm", "Disarm", "Takeoff", "RTL", "Land", "Pause", "StartMission", "ContinueMission", "ChangeAlt", "ChangeSpeed"]
            if (!_root._activeVehicle || !_root._guidedController || allowed.indexOf(action) < 0) return
            if (_root._guidedController["show" + action])
                _root._guidedController.confirmAction(_root._guidedController["action" + action])
        }
        onFlightModeRequested: mode => {
            if (!_root._activeVehicle || !_root._guidedController || !_root._activeVehicle.flightModeSetAvailable) return
            if (_root._activeVehicle.flightModes.indexOf(mode) >= 0)
                _root._guidedController.confirmAction(_root._guidedController.actionSetFlightMode, mode)
        }
        HQFullScreenControl { targetItem: hqHud }
    }

    HQPidMonitor {
        id: hqPidMonitor
        visible: _pidVisible
        x: ScreenTools.isMobile ? _mobileLeftToolX : Math.max(_toolsMargin, _root.width - width - _toolsMargin)
        y: ScreenTools.isMobile ? Math.max(_toolsMargin, _root.height - height - _toolsMargin - _mobileDockRowHeight * 2) : _root.height * 0.15
    }







    HQFlightDashboard {
        id: hqFlightDashboard
        vehicle: _activeVehicle
        visible: _dashboardVisible
        x: Math.max(_toolsMargin, (_root.width - width) / 2)
        y: _toolsMargin
        HQFullScreenControl { targetItem: hqFlightDashboard }
    }

    HQToolWarehouse {
        id: toolWarehouse
        x: Math.max(_toolsMargin, parent.width - width - _toolsMargin)
        y: _toolsMargin
        tuningVisible: _tuningVisible
        hudVisible: _hudVisible
        pidVisible: _pidVisible
        dashboardVisible: _dashboardVisible
        onToolVisibilityRequested: (key, visible) => _root.setToolVisible(key, visible)
        onSettingsRequested: {
            expanded = false
            mainWindow.showSettingsTool()
        }
    }

    Connections { target: hqExtendedTuning; function onDraggingChanged() { toolWarehouse.acceptingDrop = hqExtendedTuning.dragging; if (!hqExtendedTuning.dragging) _root.maybeStoreDraggedTool(hqExtendedTuning, "tuning") } }
    Connections { target: hqHud; function onDraggingChanged() { toolWarehouse.acceptingDrop = hqHud.dragging; if (!hqHud.dragging) _root.maybeStoreDraggedTool(hqHud, "hud") } }
    Connections { target: hqPidMonitor; function onDraggingChanged() { toolWarehouse.acceptingDrop = hqPidMonitor.dragging; if (!hqPidMonitor.dragging) _root.maybeStoreDraggedTool(hqPidMonitor, "pid") } }
    Connections { target: hqFlightDashboard; function onDraggingChanged() { toolWarehouse.acceptingDrop = hqFlightDashboard.dragging; if (!hqFlightDashboard.dragging) _root.maybeStoreDraggedTool(hqFlightDashboard, "dashboard") } }
}
