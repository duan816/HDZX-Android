import QtQuick
import QtQuick.Controls
import QtQuick.Window

import QGroundControl
import QGroundControl.Controls

Item {
    id:             _joyRoot
    objectName:      "virtualJoystickPad"

    property alias  lightColors:            mapPal.lightColors  ///< true: use light colors from QGCMapPalette for drawing
    property real   xAxis:                  0                   ///< Value range [-1,1], negative values left stick, positive values right stick
    property real   yAxis:                  0                   ///< Value range [-1,1], negative values down stick, positive values up stick
    property bool   yAxisPositiveRangeOnly: false               ///< true: value range [0,1], false: value range [-1,1]
    property bool   yAxisReCenter:          false               ///< true: snaps back to center on release, false: stays at current position on release
    property real   xPositionDelta:         0                   ///< Amount to move the control on x axis
    property real   yPositionDelta:         0                   ///< Amount to move the control on y axis
    property bool   touchActive:            false               ///< true: thumb is currently down on the pad

    property real   _centerXY:              width / 2
    property point  _pressPosition:        Qt.point(0, 0)
    property point  _pressStickPosition:   Qt.point(0, 0)
    property bool   _processTouchPoints:    false
    property color  _fgColor:               QGroundControl.globalPalette.text
    property color  _bgColor:               QGroundControl.globalPalette.window
    property real   _hatWidth:              ScreenTools.defaultFontPixelHeight
    property real   _hatWidthHalf:          _hatWidth / 2
    property bool   calculateYAxisMutex:    true
    property real   stickPositionX:         _centerXY
    property real   stickPositionY:         !yAxisReCenter ? height : height / 2
    property bool   alreadyCreated:          false

    QGCMapPalette { id: mapPal }

    onStickPositionXChanged:            calculateXAxis()
    onStickPositionYChanged:            calculateYAxis()
    onYAxisPositiveRangeOnlyChanged:    calculateYAxis()
    onYAxisReCenterChanged:             yAxisReCentered()
    onVisibleChanged:                   { if (!visible) cancelInput() }
    onEnabledChanged:                   { if (!enabled) cancelInput() }

    function cancelInput() {
        touchActive = false
        reCenter()
        // Hidden controls skip position-driven calculations; explicitly clear
        // stale axes before the next press or a window-focus interruption.
        xAxis = 0
        if (yAxisReCenter) yAxis = yAxisPositiveRangeOnly ? 0.5 : 0
    }

    Connections {
        target: _joyRoot.Window.window
        function onActiveChanged() { if (!_joyRoot.Window.window || !_joyRoot.Window.window.active) _joyRoot.cancelInput() }
    }

    function yAxisReCentered() {
        if( yAxisReCenter ) {
            yAxis = yAxisPositiveRangeOnly ? 0.5 : 0
            stickPositionY = _joyRoot.height / 2
        }
        if( !alreadyCreated && !yAxisReCenter ) {
            yAxis = yAxisPositiveRangeOnly ? 0 : -1
            stickPositionY = _joyRoot.height
        }
        if ( alreadyCreated && !yAxisReCenter ){
            yAxis = yAxisPositiveRangeOnly ? 0.5 : 0
            stickPositionY = _joyRoot.height / 2
        }
        alreadyCreated = true
        return yAxis
    }

    //We prevent Joystick to move while the screen is resizing
    function resize( yPositionAfterResize ) {
        if(_joyRoot.height <= 0) {
            return;
        }
        yPositionAfterResize = Math.max(yAxisPositiveRangeOnly ? 0 : -1, Math.min(1, yPositionAfterResize))
        calculateYAxisMutex = false
        stickPositionY = ( 1 - ( ( yPositionAfterResize + ( !yAxisPositiveRangeOnly ? 1 : 0) ) /  ( yAxisPositiveRangeOnly ? 1 : 2 ) )) * _joyRoot.height // Reverse the CalculateYAxis Procedure
        stickPositionX = _joyRoot.width / 2 // Manual recenter
        calculateYAxisMutex = true
        calculateYAxis()
    }

    function calculateXAxis() {
        if(!_joyRoot.visible) {
            return;
        }
        var xAxisTemp = width > 0 ? stickPositionX / width : 0.5
        xAxisTemp *= 2.0
        xAxisTemp -= 1.0
        xAxis = xAxisTemp
    }

    function calculateYAxis() {
        if(!_joyRoot.visible) {
            return;
        }
        if(!calculateYAxisMutex) {
            return;
        }
        var fullRange = yAxisPositiveRangeOnly ? 1 : 2
        var pctUp = height > 0 ? 1.0 - (stickPositionY / height) : 0.5
        var rangeUp = pctUp * fullRange
        if (!yAxisPositiveRangeOnly) {
            rangeUp -= 1
        }
        yAxis = rangeUp
    }

    function reCenter() {
        _processTouchPoints = false
        _centerXY = _joyRoot.width / 2 // Reload before using it to make sure of using the right value
        // Move control back to original position
        xPositionDelta = 0
        yPositionDelta = 0

        // Re-Center sticks as needed
        stickPositionX = _centerXY
        if (yAxisReCenter) {
            stickPositionY = _centerXY
        }
    }

    function thumbDown(touchPoints) {
        // Input coordinates belong to this pad. Do not reject a valid right-pad
        // press using page-wide offsets (which change with HUD/layout scaling).
        if (!touchPoints.length || width <= 0 || height <= 0) return
        _processTouchPoints = true
        // Keep the current throttle/center on contact; only subsequent drag
        // changes the command, even if the first touch is near the pad edge.
        _pressPosition = Qt.point(touchPoints[0].x, touchPoints[0].y)
        _pressStickPosition = Qt.point(stickPositionX, stickPositionY)
    }

    /*
    // Keep in for debugging
    Column {
        QGCLabel { text: xAxis }
        QGCLabel { text: yAxis }
    }
    */

    Image {
        anchors.fill:       parent
        source:             "/res/JoystickBezelLight.png"
        mipmap:             true
        smooth:             true
    }

    Rectangle {
        anchors.fill:       parent
        radius:             width / 2
        color:              _bgColor
        opacity:            0.5

        Rectangle {
            anchors.margins:    parent.width / 4
            anchors.fill:       parent
            radius:             width / 2
            border.color:       _fgColor
            border.width:       2
            color:              "transparent"
        }

        Rectangle {
            anchors.fill:       parent
            radius:             width / 2
            border.color:       _fgColor
            border.width:       2
            color:              "transparent"
        }
    }

    QGCColoredImage {
        color:                      _fgColor
        visible:                    yAxisPositiveRangeOnly
        height:                     ScreenTools.defaultFontPixelHeight
        width:                      height
        sourceSize.height:          height
        mipmap:                     true
        fillMode:                   Image.PreserveAspectFit
        source:                     "/res/clockwise-arrow.svg"
        anchors.right:              parent.right
        anchors.rightMargin:        ScreenTools.defaultFontPixelWidth
        anchors.verticalCenter:     parent.verticalCenter
    }

    QGCColoredImage {
        color:                      _fgColor
        visible:                    yAxisPositiveRangeOnly
        height:                     ScreenTools.defaultFontPixelHeight
        width:                      height
        sourceSize.height:          height
        mipmap:                     true
        fillMode:                   Image.PreserveAspectFit
        source:                     "/res/counter-clockwise-arrow.svg"
        anchors.left:               parent.left
        anchors.leftMargin:         ScreenTools.defaultFontPixelWidth
        anchors.verticalCenter:     parent.verticalCenter
    }

    QGCColoredImage {
        color:                      _fgColor
        visible:                    yAxisPositiveRangeOnly
        height:                     ScreenTools.defaultFontPixelHeight
        width:                      height
        sourceSize.height:          height
        mipmap:                     true
        fillMode:                   Image.PreserveAspectFit
        source:                     "/res/chevron-up.svg"
        anchors.top:                parent.top
        anchors.topMargin:          ScreenTools.defaultFontPixelWidth
        anchors.horizontalCenter:   parent.horizontalCenter
    }

    QGCColoredImage {
        color:                      _fgColor
        visible:                    yAxisPositiveRangeOnly
        height:                     ScreenTools.defaultFontPixelHeight
        width:                      height
        sourceSize.height:          height
        mipmap:                     true
        fillMode:                   Image.PreserveAspectFit
        source:                     "/res/chevron-down.svg"
        anchors.bottom:             parent.bottom
        anchors.bottomMargin:       ScreenTools.defaultFontPixelWidth
        anchors.horizontalCenter:   parent.horizontalCenter
    }

    Rectangle {
        width:          _hatWidth
        height:         _hatWidth
        radius:         _hatWidthHalf
        border.color:   _fgColor
        border.width:   1
        color:          Qt.rgba(_fgColor.r, _fgColor.g, _fgColor.b, 0.5)
        x:              stickPositionX - _hatWidthHalf
        y:              stickPositionY - _hatWidthHalf
    }

    Connections {
        target: touchPoint

        onXChanged: {
            if (_processTouchPoints) {
                _joyRoot.stickPositionX = Math.max(Math.min(_pressStickPosition.x + touchPoint.x - _pressPosition.x, _joyRoot.width), 0)
            }
        }
        onYChanged: {
            if (_processTouchPoints) {
                _joyRoot.stickPositionY = Math.max(Math.min(_pressStickPosition.y + touchPoint.y - _pressPosition.y, _joyRoot.height), 0)
            }
        }
    }

    MultiPointTouchArea {
        anchors.fill:           parent
        anchors.bottomMargin:   yAxisReCenter ? 0 : -_hatWidthHalf
        minimumTouchPoints:     1
        maximumTouchPoints:     1
        touchPoints:            [ TouchPoint { id: touchPoint } ]
        onPressed: touchPoints => {
            _joyRoot.touchActive = true
            _joyRoot.thumbDown(touchPoints)
        }
        onReleased: {
            _joyRoot.touchActive = false
            _joyRoot.reCenter()
        }
        onCanceled: {
            _joyRoot.touchActive = false
            _joyRoot.reCenter()
        }
    }
}
