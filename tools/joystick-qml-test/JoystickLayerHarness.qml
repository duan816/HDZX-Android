import QtQuick
import QGroundControl
Item {
    id: _root
    width: 1000; height: 600
    property real sidebar: 0
    property real _toolsMargin: 12
    property var _activeVehicle: QGroundControl.testVehicle
    property var parentToolInsets: QtObject { property real bottomEdgeLeftInset: 0 }
    QtObject { id: toolStrip; property real width: 60; property real height: 100; property real x: _root.sidebar; property real y: 0 }
    QtObject { id: _pipView; property bool visible: false }
    QtObject { id: bottomRightRowLayout; property real height: 40 }
    Rectangle { objectName: "ordinaryInstrument"; width: 240; height: 200; anchors.right: parent.right; anchors.bottom: parent.bottom; z: QGroundControl.zOrderTopMost+22; MouseArea { anchors.fill: parent } }
    Loader {
        id:                         virtualJoystickMultiTouch
        objectName:                 "virtualJoystickLayer"
        // Manual controls stay above ordinary instruments; configuration and modal layers remain above them.
        z:                          QGroundControl.zOrderTopMost + 50
        anchors.right:              parent.right
        anchors.rightMargin:        Math.max(_toolsMargin, toolStrip.width / 2)
        height:                     Math.min(Math.min(parent.height * 0.25, ScreenTools.defaultFontPixelWidth * 16)
                                                * QGroundControl.settingsManager.appSettings.virtualJoystickSize.rawValue / 100,
                                                parent.height * 0.4, Math.max(0, width * 0.45))
        visible:                    _virtualJoystickEnabled && !QGroundControl.videoManager.fullScreen && !(_activeVehicle ? _activeVehicle.usingHighLatencyLink : false)
        anchors.bottom:             parent.bottom
        anchors.bottomMargin:       bottomLoaderMargin
        anchors.left:               parent.left
        anchors.leftMargin:         ( y > toolStrip.y + toolStrip.height ? toolStrip.width / 2 : toolStrip.width * 1.05 + toolStrip.x)
        source:                     "../../src/FlyView/VirtualJoystick.qml"
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

}
