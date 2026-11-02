import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

// Important Note: Toolbar buttons must manage their checked state manually in order to support
// view switch prevention. This means they can't be checkable or autoExclusive.

Button {
    id:                 button
    height:             ScreenTools.defaultFontPixelHeight * 3
    leftPadding:        _horizontalMargin
    rightPadding:       _horizontalMargin
    checkable:          false

    property bool logo: false

    property real _horizontalMargin: ScreenTools.defaultFontPixelWidth

    onCheckedChanged: checkable = false

    background: Rectangle {
        anchors.fill:   parent
        color:          button.checked ? qgcPal.buttonHighlight : Qt.rgba(0,0,0,0)
        Behavior on color { ColorAnimation { duration: 140 } }
        border.color:   "red"
        border.width:   QGroundControl.corePlugin.showTouchAreas ? 3 : 0
        HQButtonRipple { control: button }
    }

    contentItem: Row {
        scale: button.down ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: button.down ? 120 : 320; easing.type: button.down ? Easing.OutCubic : Easing.OutBack; easing.overshoot: 0.35 } }
        spacing:                ScreenTools.defaultFontPixelWidth
        anchors.verticalCenter: button.verticalCenter
        // Brand logos may be either SVG or PNG. Keep their original colours.
        Image {
            visible:                button.logo
            height:                 ScreenTools.defaultFontPixelHeight * 2
            width:                  height
            source:                 visible ? button.icon.source : ""
            sourceSize:             Qt.size(256, 256)
            asynchronous:           true
            fillMode:               Image.PreserveAspectFit
            mipmap:                 true
            anchors.verticalCenter: parent.verticalCenter
        }
        QGCColoredImage {
            visible:                !button.logo
            height:                 ScreenTools.defaultFontPixelHeight * 2
            width:                  height
            sourceSize.height:      parent.height
            fillMode:               Image.PreserveAspectFit
            color:                  button.checked ? qgcPal.buttonHighlightText : qgcPal.buttonText
            source:                 visible ? button.icon.source : ""
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            id:                     _label
            visible:                text !== ""
            text:                   button.text
            color:                  button.checked ? qgcPal.buttonHighlightText : qgcPal.buttonText
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
