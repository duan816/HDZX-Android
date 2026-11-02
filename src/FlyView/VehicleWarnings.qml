import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import "HQWarningPresentation.js" as WarningPresentation

Rectangle {
    id: root
    objectName: "vehicleWarnings"
    anchors.margins: -ScreenTools.defaultFontPixelHeight
    height: Math.min(warningsCol.implicitHeight + padding * 2,
                     viewportHeight * (detailsExpanded ? 0.62 : 0.40))
    width: Math.min(ScreenTools.defaultFontPixelWidth * 52, parent ? parent.width * 0.88 : 500)
    color: Qt.rgba(0.04, 0.08, 0.12, 0.28)
    radius: ScreenTools.defaultFontPixelWidth / 2
    visible: (!!warning || persistentWarnings.length > 0) && !!vehicle
             && (!vehicle.vehicleLinkManager || !vehicle.vehicleLinkManager.communicationLost)
    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool detailsExpanded: false
    readonly property real viewportHeight: parent ? parent.height : 667
    readonly property real padding: ScreenTools.defaultFontPixelHeight * 0.5
    readonly property var warningRows: vehicle && vehicle.recentWarnings ? vehicle.recentWarnings : []
    readonly property var persistentWarnings: WarningPresentation.persistent(warningRows)
    readonly property var primaryFault: persistentWarnings.length ? persistentWarnings[0] : null
    readonly property var warning: WarningPresentation.speaking(QGroundControl.speakingAlert, vehicle ? vehicle.id : -2, warningRows)
    readonly property var detailWarnings: warning && !persistentWarnings.some(row => row.text === warning.text)
        ? persistentWarnings.concat([warning]) : persistentWarnings
    onVehicleChanged: detailsExpanded = false
    onVisibleChanged: if (!visible) detailsExpanded = false

    ColumnLayout {
        id: warningsCol
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: ScreenTools.defaultFontPixelHeight * 0.35
        QGCLabel {
            objectName: "vehiclePersistentWarningsTitle"
            Layout.fillWidth: true
            visible: !!root.primaryFault
            text: qsTr("持续故障 · %1 项").arg(root.persistentWarnings.length)
            color: "#EB6B64"
            font.pointSize: ScreenTools.smallFontPointSize
            horizontalAlignment: Text.AlignHCenter
        }
        QGCLabel {
            objectName: "vehiclePersistentWarnings"
            Layout.fillWidth: true
            visible: !!root.primaryFault
            text: WarningPresentation.bilingual(root.primaryFault)
            color: "#EB6B64"
            font.pointSize: ScreenTools.mediumFontPointSize
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            style: Text.Outline
            styleColor: "#60201010"
        }
        Rectangle {
            visible: root.persistentWarnings.length > 0 && !!root.warning
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#50FFFFFF"
        }
        QGCLabel {
            objectName: "vehicleSpeakingWarningTitle"
            Layout.fillWidth: true
            visible: !!root.warning
            text: qsTr("正在播报")
            color: "#FF3030"
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
        }
        QGCLabel {
            objectName: "vehicleWarningText"
            Layout.fillWidth: true
            visible: !!root.warning
            color: "#FF3030"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pointSize: ScreenTools.largeFontPointSize
            text: root.warning ? root.warning.text : ""
            style: Text.Outline
            styleColor: "#60201010"
        }
        QGCLabel {
            objectName: "vehicleWarningTranslation"
            Layout.fillWidth: true
            visible: !!root.warning && text !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#FF3030"
            font.pointSize: ScreenTools.mediumFontPointSize
            text: root.warning ? root.warning.translation : ""
        }
        QGCLabel {
            objectName: "vehicleWarningDetailsToggle"
            Layout.alignment: Qt.AlignHCenter
            text: root.detailsExpanded ? qsTr("收起详情 ∧") : qsTr("查看全部报错与解决方法 ∨")
            color: "#DAEAF4"
            font.pointSize: ScreenTools.smallFontPointSize
            topPadding: root.padding * 0.4
            bottomPadding: root.padding * 0.4
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.detailsExpanded = !root.detailsExpanded
            }
        }
        // Keep the final text layout while only its viewport reveals. A new
        // click reverses from the current height, including halfway through.
        Item {
            objectName: "vehicleWarningDetailsViewport"
            Layout.fillWidth: true
            implicitHeight: root.detailsExpanded ? detailsScroll.height : 0
            clip: true
            Behavior on implicitHeight { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            ScrollView {
                id: detailsScroll
                width: parent.width
                height: Math.min(detailsColumn.implicitHeight, root.viewportHeight * 0.22)
                enabled: root.detailsExpanded
                visible: parent.height > 0
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    id: detailsColumn
                    width: detailsScroll.availableWidth
                    Repeater {
                        model: root.detailWarnings
                        QGCLabel {
                            required property var modelData
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: "#E1EAF0"
                            text: WarningPresentation.bilingual(modelData)
                                  + (modelData.explanation ? "\n" + modelData.explanation : "")
                                  + (modelData.solution ? "\n" + qsTr("解决方法：%1").arg(modelData.solution) : "")
                        }
                    }
                }
            }
        }
    }
}
