import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Button {
    id:             control
    padding:        ScreenTools.defaultFontPixelWidth
    hoverEnabled:   !ScreenTools.isMobile
    autoExclusive:  true
    icon.color:     textColor

    property color textColor: checked || pressed ? qgcPal.buttonHighlightText : qgcPal.buttonText
    property bool expandable: false
    property bool expanded:   false
    property bool animationsEnabled: true

    signal toggleExpand()

    QGCPalette {
        id:                 qgcPal
        colorGroupEnabled:  control.enabled
    }

    background: Rectangle {
        color: control.hovered && !control.checked ? qgcPal.windowShade : "transparent"
        radius: 10
        Behavior on color { ColorAnimation { duration: 130 } }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: qgcPal.buttonHighlight
            opacity: control.checked ? 1 : 0
            Behavior on opacity { enabled: control.animationsEnabled; OpacityAnimator { duration: 180; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: parent.height * 0.48
            radius: 1.5
            color: qgcPal.primaryButton
            visible: control.checked
        }
        HQButtonRipple { control: control; animationsEnabled: control.animationsEnabled }
    }

    contentItem: RowLayout {
        spacing: ScreenTools.defaultFontPixelWidth
        scale: control.down ? 0.96 : 1
        Behavior on scale { enabled: control.animationsEnabled; NumberAnimation { duration: control.down ? 120 : 320; easing.type: control.down ? Easing.OutCubic : Easing.OutBack; easing.overshoot: 0.35 } }

        Item {
            width: ScreenTools.defaultFontPixelHeight
            height: width
            QGCColoredImage {
                anchors.fill:parent
                visible: !String(control.icon.source).endsWith("HQLogo.png")
            source: control.icon.source
            color:  control.icon.color
            }
            Image {
                anchors.fill:parent
                visible: String(control.icon.source).endsWith("HQLogo.png")
                source:visible?control.icon.source:""
                sourceSize:Qt.size(parent.width*2,parent.height*2)
                fillMode:Image.PreserveAspectFit
                mipmap:true
            }
        }

        QGCLabel {
            id:                     displayText
            Layout.fillWidth:       true
            text:                   control.text
            color:                  control.textColor
            horizontalAlignment:    QGCLabel.AlignLeft
        }

        QGCColoredImage {
            visible:    control.expandable
            source:     "/InstrumentValueIcons/cheveron-right.svg"
            color:      control.textColor
            width:      ScreenTools.defaultFontPixelHeight * 0.75
            height:     width
            rotation:   control.expanded ? 90 : 0
            Behavior on rotation { enabled: control.animationsEnabled; RotationAnimator { duration: 150; easing.type: Easing.OutCubic } }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -ScreenTools.defaultFontPixelWidth
                onClicked: control.toggleExpand()
            }
        }
    }
}
