pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import "../FlightMap/Widgets" as FlightWidgets

Rectangle {
    id: root
    required property var vehicle
    property bool current: false
    property bool selected: false
    signal activateRequested()
    signal selectionRequested()
    readonly property real heading: vehicle && vehicle.heading ? Number(vehicle.heading.rawValue) : NaN
    readonly property string headingText: Number.isFinite(heading) ? (((heading % 360) + 360) % 360).toFixed(0) + "°" : "--°"
    readonly property bool lost: !vehicle || !vehicle.vehicleLinkManager || vehicle.vehicleLinkManager.communicationLost
    implicitHeight: content.implicitHeight + ScreenTools.defaultFontPixelHeight
    implicitWidth: ScreenTools.defaultFontPixelWidth * 34
    color: current ? palette.buttonHighlight : palette.windowShade
    radius: ScreenTools.defaultBorderRadius
    border.width: selected ? 2 : 1
    border.color: current ? palette.colorGreen : palette.groupBorder
    QGCPalette { id: palette }
    MouseArea { anchors.fill: parent; onClicked: root.activateRequested() }
    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.5
        spacing: ScreenTools.defaultFontPixelHeight * 0.35
        RowLayout {
            Layout.fillWidth: true
            QGCLabel { font.family: ScreenTools.hqUiFontFamily; Layout.fillWidth: true; font.bold: true; text: root.vehicle ? qsTr("%1 号机").arg(root.vehicle.id) : "--" }
            QGCLabel { font.family: ScreenTools.hqUiFontFamily; text: root.current ? qsTr("主调试") : ""; color: palette.colorGreen }
            QGCCheckBox { checked: root.selected; text: qsTr("批量"); onClicked: root.selectionRequested() }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth
            Rectangle {
                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 3.2
                Layout.preferredHeight: Layout.preferredWidth
                radius: width / 2
                color: palette.window
                border.color: palette.groupBorder
                QGCLabel { font.family: ScreenTools.hqUiFontFamily; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: "N"; font.pointSize: ScreenTools.smallFontPointSize }
                FlightWidgets.CompassHeadingIndicator { compassSize:parent.width*1.55; heading:root.heading; simplified:false; visible:Number.isFinite(root.heading) }
            }
            ColumnLayout {
                Layout.fillWidth: true
                QGCLabel { font.family: ScreenTools.hqUiFontFamily; objectName: "vehicleHeadingReadout"; text: qsTr("航向 %1").arg(root.headingText); font.bold: true; Layout.fillWidth: true }
                FlightModeMenu { currentVehicle: root.vehicle; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pointSize: ScreenTools.defaultFontPointSize }
            }
        }
        QGCLabel { font.family: ScreenTools.hqUiFontFamily;
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: root.lost ? palette.warningText : palette.text
            text: root.lost ? qsTr("通信中断") : root.vehicle && root.vehicle.armed ? qsTr("已解锁") : qsTr("未解锁")
        }
        QGCLabel { font.family: ScreenTools.hqUiFontFamily;
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("相对高度 %1 m   地速 %2 m/s")
                .arg(root.valueText(root.vehicle ? root.vehicle.altitudeRelative : null))
                .arg(root.valueText(root.vehicle ? root.vehicle.groundSpeed : null))
        }
    }
    function valueText(fact) {
        const value = fact ? Number(fact.rawValue) : NaN
        return Number.isFinite(value) ? value.toFixed(1) : "--"
    }
}
