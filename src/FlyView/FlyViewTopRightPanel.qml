import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap

Rectangle {
    id:             topRightPanel
    width:          Math.min(contentWidth, parent ? parent.width * (ScreenTools.isMobile ? 0.62 : 0.36) : contentWidth)
    height:         Math.max(contentHeight, minimumHeight)
    color:          qgcPal.toolbarBackground
    radius:         ScreenTools.defaultFontPixelHeight / 2
    visible:        !QGroundControl.videoManager.fullScreen && _multipleVehicles && _settingEnableMVPanel
    clip:           true

    property bool _settingEnableMVPanel:    QGroundControl.settingsManager.appSettings.enableMultiVehiclePanel.value
    property bool  _multipleVehicles:       QGroundControl.multiVehicleManager.vehicles.count > 1
    property var   vehicles:                QGroundControl.multiVehicleManager.vehicles
    property var   selectedVehicles:        QGroundControl.multiVehicleManager.selectedVehicles
    property real  contentWidth:            Math.max(
                                                multiVehicleList.implicitWidth,
                                                swipeViewContainer.implicitWidth
                                            ) + ScreenTools.defaultFontPixelHeight
    property real  contentHeight:           Math.min(
                                                maximumHeight,
                                                topRightPanelColumnLayout.implicitHeight + topRightPanelColumnLayout.anchors.margins * 2
                                            )
    property real  minimumHeight:           swipeViewContainer.implicitHeight
    property real  maximumHeight
    property bool  _proximityWarningEnabled: false
    property real  _nearestVehicleDistance: -1
    property string _nearestVehiclePair: ""

    function updateNearestVehicleDistance() {
        var nearest = -1
        var pair = ""
        for (var i = 0; i < vehicles.count; ++i) {
            var first = vehicles.get(i)
            if (!first || !first.coordinate || !first.coordinate.isValid)
                continue
            for (var j = i + 1; j < vehicles.count; ++j) {
                var second = vehicles.get(j)
                if (!second || !second.coordinate || !second.coordinate.isValid)
                    continue
                var distance = first.coordinate.distanceTo(second.coordinate)
                if (nearest < 0 || distance < nearest) {
                    nearest = distance
                    pair = first.id + " / " + second.id
                }
            }
        }
        _nearestVehicleDistance = nearest
        _nearestVehiclePair = pair
    }

    QGCPalette { id: qgcPal }

    Timer {
        interval: 500
        repeat: true
        running: topRightPanel.visible && _proximityWarningEnabled
        onTriggered: updateNearestVehicleDistance()
    }

    DeadMouseArea {
        anchors.fill:       parent
    }

    ColumnLayout {
        id:                 topRightPanelColumnLayout
        anchors.fill:       parent
        anchors.margins:    topRightPanel.color.a ? ScreenTools.defaultFontPixelHeight / 2 : 0
        spacing:            ScreenTools.defaultFontPixelWidth * 0.75 // _layoutMargin

        QGCLabel {
            Layout.fillWidth: true
            text: globals.activeVehicle
                    ? qsTr("主调试飞行器：%1号机").arg(globals.activeVehicle.id)
                    : qsTr("主调试飞行器：未选择")
            color: "#6FF4D2"
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        QGCLabel {
            Layout.fillWidth: true
            text: qsTr("点击飞机卡片切换调试对象；勾选“批量”用于多机操作")
            color: qgcPal.text
            font.pointSize: ScreenTools.smallFontPointSize
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        QGCCheckBox {
            Layout.fillWidth: true
            text: qsTr("启用多机间距监视（只告警）")
            checked: _proximityWarningEnabled
            onClicked: {
                _proximityWarningEnabled = checked
                if (checked)
                    updateNearestVehicleDistance()
            }
        }

        QGCLabel {
            Layout.fillWidth: true
            visible: _proximityWarningEnabled
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: _nearestVehicleDistance >= 0 && _nearestVehicleDistance < 10 ? qgcPal.warningText : qgcPal.text
            font.bold: _nearestVehicleDistance >= 0 && _nearestVehicleDistance < 10
            text: _nearestVehicleDistance < 0
                    ? qsTr("等待多机定位…")
                    : (_nearestVehicleDistance < 10
                       ? qsTr("警告：%1 号机水平间距仅 %2 米").arg(_nearestVehiclePair).arg(_nearestVehicleDistance.toFixed(1))
                       : qsTr("最近为 %1 号机，水平间距 %2 米").arg(_nearestVehiclePair).arg(_nearestVehicleDistance.toFixed(1)))
        }

        QGCLabel {
            Layout.fillWidth: true
            visible: _proximityWarningEnabled
            wrapMode: Text.WordWrap
            color: qgcPal.warningText
            font.pointSize: ScreenTools.smallFontPointSize
            text: qsTr("地面站仅能提醒，不能代替飞控避碰、RTK 和人工安全间隔。")
        }

        MultiVehicleList {
            id:                    multiVehicleList
            Layout.fillWidth:      true
            Layout.fillHeight:     true

            Rectangle {
                anchors.fill: parent
                visible:      topRightPanel.height === maximumHeight

                Rectangle {
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top
                    anchors.margins:    0
                    height:             1
                    color:              QGroundControl.globalPalette.groupBorder
                }

                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.00; color: topRightPanel.color }
                    GradientStop { position: 0.05; color: "transparent" }

                    GradientStop { position: 0.95; color: "transparent" }
                    GradientStop { position: 1.00; color: topRightPanel.color }
                }

                Rectangle {
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.bottom:     parent.bottom
                    anchors.margins:    0
                    height:             1
                    color:              QGroundControl.globalPalette.groupBorder
                }
            }

        }

        Rectangle {
            id:                     swipeViewContainer
            Layout.fillWidth:       true
            implicitHeight:         swipePages.implicitHeight
            implicitWidth:          swipePages.implicitWidth
            color:                  "transparent"

            QGCSwipeView {
                id:                swipePages
                anchors.fill:      parent
                spacing:           ScreenTools.defaultFontPixelHeight
                implicitHeight:    Math.max(buttonsPage.implicitHeight, photoVideoPage.implicitHeight)
                implicitWidth:     Math.max(buttonsPage.implicitWidth, photoVideoPage.implicitWidth)

                MvPanelPage {
                    id:                buttonsPage
                    implicitHeight:    buttonsColumnLayout.implicitHeight + ScreenTools.defaultFontPixelHeight * 2
                    implicitWidth:     buttonsColumnLayout.implicitWidth + ScreenTools.defaultFontPixelHeight * 2

                    ColumnLayout {
                        id:                     buttonsColumnLayout
                        anchors.right:          parent.right
                        anchors.left:           parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing:                ScreenTools.defaultFontPixelHeight / 2
                        implicitHeight:         Math.max(selectionRowLayout.height, actionRowLayout.height) + ScreenTools.defaultFontPixelHeight * 2
                        implicitWidth:          Math.max(selectionRowLayout.width, actionRowLayout.width) + ScreenTools.defaultFontPixelHeight * 4

                        QGCLabel {
                            text: {
                                let ids = Array.from({length: selectedVehicles.count}, (_, i) =>
                                    selectedVehicles.get(i).id
                                ).sort((a, b) => a - b)
                                .join(", ")
                                return qsTr("Vehicles Selected: ") + (ids ? ids : "-")
                            }
                            Layout.alignment:   Qt.AlignHCenter
                        }

                        RowLayout {
                            id:                 selectionRowLayout
                            Layout.alignment:   Qt.AlignHCenter

                            QGCButton {
                                text:                  qsTr("Select All")
                                enabled:               multiVehicleList.selectedVehicles && multiVehicleList.selectedVehicles.count !== QGroundControl.multiVehicleManager.vehicles.count
                                onClicked:             multiVehicleList.selectAll()
                            }

                            QGCButton {
                                text:                  qsTr("Deselect All")
                                enabled:               multiVehicleList.selectedVehicles && multiVehicleList.selectedVehicles.count > 0
                                onClicked:             multiVehicleList.deselectAll()
                            }

                        }


                        QGCLabel {
                            text:              qsTr("Multi Vehicle Actions")
                            Layout.alignment:  Qt.AlignHCenter
                        }

                        RowLayout {
                            id:                actionRowLayout
                            Layout.alignment:  Qt.AlignHCenter

                            QGCButton {
                                text:                  qsTr("Arm")
                                enabled:               multiVehicleList.armAvailable()
                                onClicked:             _guidedController.confirmAction(_guidedController.actionMVArm)
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.75
                                leftPadding:           0
                                rightPadding:          0
                            }

                            QGCButton {
                                text:                  qsTr("Disarm")
                                enabled:               multiVehicleList.disarmAvailable()
                                onClicked:             _guidedController.confirmAction(_guidedController.actionMVDisarm)
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.75
                                leftPadding:           0
                                rightPadding:          0
                            }

                            QGCButton {
                                text:                  qsTr("Start")
                                enabled:               multiVehicleList.startAvailable()
                                onClicked:             _guidedController.confirmAction(_guidedController.actionMVStartMission)
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.75
                                leftPadding:           0
                                rightPadding:          0
                            }

                            QGCButton {
                                text:                  qsTr("Pause")
                                enabled:               multiVehicleList.pauseAvailable()
                                onClicked:             _guidedController.confirmAction(_guidedController.actionMVPause)
                                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 2.75
                                leftPadding:           0
                                rightPadding:          0
                            }
                        }
                    }
                } // Page 1

                MvPanelPage {

                    id:                  photoVideoPage
                    implicitHeight:      photoVideoControlLoader.implicitHeight + ScreenTools.defaultFontPixelHeight * 2
                    implicitWidth:       photoVideoControlLoader.implicitWidth + ScreenTools.defaultFontPixelHeight * 2

                    // We use a Loader to load the photoVideoControlComponent only when the active vehicle is not null
                    // This make it easier to implement PhotoVideoControl without having to check for the mavlink camera
                    // to be null all over the place

                    Loader {
                        id:                         photoVideoControlLoader
                        anchors.horizontalCenter:   parent.horizontalCenter
                        sourceComponent:            globals.activeVehicle ? photoVideoControlComponent : undefined

                        property real rightEdgeCenterInset: visible ? parent.width - x : 0

                        Component {
                            id: photoVideoControlComponent

                            PhotoVideoControl {
                            }
                        }
                    }
                } // Page 2
            } // QGCSwipeView

            QGCPageIndicator {
                id:                       pageIndicator
                count:                    swipePages.count
                currentIndex:             swipePages.currentIndex
                anchors.bottom:           parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.margins:          ScreenTools.defaultFontPixelHeight / 4

                delegate: Rectangle {
                    height:    ScreenTools.defaultFontPixelHeight  / 2
                    width:     height
                    radius:    width / 2
                    color:     model.index === pageIndicator.currentIndex ? qgcPal.text : qgcPal.button
                    opacity:   model.index === pageIndicator.currentIndex ? 0.9 : 0.3
                }
            }
        }
    }
}
