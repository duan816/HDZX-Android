import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Standard push button control:
///     If there is both an icon and text the icon will be to the left of the text
///     If icon only, icon will be centered
Button {
    property bool primary: false
    property bool showBorder: qgcPal.globalTheme === QGCPalette.Light
    property real backRadius: ScreenTools.defaultBorderRadius
    property real heightFactor: 0.5
    property string iconSource: ""
    property real fontWeight: Font.Normal // default for qml Text
    property real pointSize: ScreenTools.defaultFontPointSize

    property alias wrapMode: text.wrapMode
    property alias horizontalAlignment: text.horizontalAlignment
    property alias backgroundColor: backRect.color
    property alias textColor: text.color

    id: control
    hoverEnabled: !ScreenTools.isMobile
    topPadding: _verticalPadding
    bottomPadding: _verticalPadding
    leftPadding: _horizontalPadding
    rightPadding: _horizontalPadding
    focusPolicy: Qt.ClickFocus
    font.family: ScreenTools.normalFontFamily
    text: ""

    property bool _showHighlight: enabled && checked
    property int _horizontalPadding: ScreenTools.defaultFontPixelWidth * 2
    property int _verticalPadding: Math.round(ScreenTools.defaultFontPixelHeight * heightFactor) - (iconSource === "" ? 0 : (_iconHeight - ScreenTools.defaultFontPixelHeight)  / 2)
    property real _iconHeight: text.height * 1.5

    QGCPalette { id: qgcPal; colorGroupEnabled: control.enabled }

    background: Rectangle {
        id: backRect
        radius: control.backRadius
        implicitWidth: ScreenTools.implicitButtonWidth
        implicitHeight: ScreenTools.implicitButtonHeight
        border.width: control.showBorder ? 1 : 0
        border.color: qgcPal.buttonBorder
        color: control.primary ? qgcPal.primaryButton : qgcPal.button
        scale: control.down ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: control.down ? 120 : 320; easing.type: control.down ? Easing.OutCubic : Easing.OutBack; easing.overshoot: 0.35 } }

        Rectangle {
            anchors.fill: parent
            color: qgcPal.buttonHighlight
            opacity: control.checked ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: control.down ? 120 : 220; easing.type: Easing.OutCubic }
            }
            radius: parent.radius
        }
        // A recessed edge gives depth without a bright full-button flash.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, backRect.radius - 1)
            color: "transparent"
            border.width: 2
            border.color: "#55020B13"
            opacity: control.down ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
        HQButtonRipple { control: control }
    }

    contentItem: RowLayout {
        spacing: ScreenTools.defaultFontPixelWidth
        scale: control.down ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: control.down ? 120 : 320; easing.type: control.down ? Easing.OutCubic : Easing.OutBack; easing.overshoot: 0.35 } }

        QGCColoredImage {
            id: icon
            Layout.alignment: Qt.AlignHCenter
            source: control.iconSource
            Layout.preferredHeight: control._iconHeight
            Layout.preferredWidth: control._iconHeight
            color: text.color
            fillMode: Image.PreserveAspectFit
            sourceSize.height: height
            visible: control.iconSource !== ""
        }

        QGCLabel {
            id: text
            Layout.alignment: Qt.AlignHCenter
            text: control.text
            font.pointSize: control.pointSize
            font.family: control.font.family
            font.weight: control.fontWeight
            color: control._showHighlight ? qgcPal.buttonHighlightText : (control.primary ? qgcPal.primaryButtonText : qgcPal.buttonText)
            visible: control.text !== ""
        }
    }
}
