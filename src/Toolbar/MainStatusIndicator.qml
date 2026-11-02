import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

RowLayout {
    id:         control
    spacing:    ScreenTools.defaultFontPixelWidth

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _armed:             _activeVehicle ? _activeVehicle.armed : false
    property real   _margins:           ScreenTools.defaultFontPixelWidth
    property real   _spacing:           ScreenTools.defaultFontPixelWidth / 2
    property bool   _allowForceArm:      false
    property bool   _healthAndArmingChecksSupported: _activeVehicle ? _activeVehicle.healthAndArmingCheckReport.supported : false
    property bool   _vehicleFlies:      _activeVehicle ? _activeVehicle.airShip || _activeVehicle.fixedWing || _activeVehicle.vtol || _activeVehicle.multiRotor : false
    property var    _vehicleInAir:      _activeVehicle ? _activeVehicle.flying || _activeVehicle.landing : false
    property bool   _vtolInFWDFlight:   _activeVehicle ? _activeVehicle.vtolInFwdFlight : false

    function dropMainStatusIndicator() {
        let overallStatusComponent = _activeVehicle ? overallStatusIndicatorPage : overallStatusOfflineIndicatorPage
        mainWindow.showIndicatorDrawer(overallStatusComponent, control)
    }

    QGCPalette { id: qgcPal }

    readonly property var connectionAttempt: typeof mainWindow !== "undefined" ? mainWindow.hdzxConnectionAttempt : null
    property alias statusPresentation: statusModel

    HDZXVehicleStatus {
        id: statusModel
        vehicle: control._activeVehicle
        waitingForHeartbeat: !!control.connectionAttempt && control.connectionAttempt.waiting
        connectionFailed: !!control.connectionAttempt && control.connectionAttempt.failed
        connectionFailureText: control.connectionAttempt ? control.connectionAttempt.failureText : ""
    }

    HDZXStatusBadge {
        objectName: "hdzxMainStatusBadge"
        Layout.fillHeight: true
        Layout.preferredWidth: implicitWidth
        status: statusModel
        progress: statusModel.connected ? control._activeVehicle.loadProgress : NaN
        onClicked: control.dropMainStatusIndicator()
    }

    QGCColoredImage {
        id: vehicleMessagesIcon
        objectName: "hdzxVehicleMessagesIcon"
        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 2
        Layout.preferredHeight: width
        source: "/res/VehicleMessages.png"
        color: control._activeVehicle && control._activeVehicle.messageTypeError ? qgcPal.colorRed
            : control._activeVehicle && control._activeVehicle.messageTypeWarning ? qgcPal.colorOrange : qgcPal.text
        sourceSize.width: width
        fillMode: Image.PreserveAspectFit
        visible: control._activeVehicle && control._activeVehicle.messageCount > 0
        QGCMouseArea {
            objectName: "hdzxVehicleMessagesAction"
            anchors.fill: parent
            onClicked: control.dropMainStatusIndicator()
        }
    }

    QGCLabel {
        id:                 vtolModeLabel
        Layout.fillHeight:  true
        verticalAlignment:  Text.AlignVCenter
        text:               _vtolInFWDFlight ? qsTr("FW(vtol)") : qsTr("MR(vtol)")
        color:              qgcPal.text
        font.pointSize:     _vehicleInAir ? ScreenTools.largeFontPointSize : ScreenTools.defaultFontPointSize
        visible:            _activeVehicle && _activeVehicle.vtol

        QGCMouseArea {
            anchors.fill: parent
            onClicked: {
                if (_vehicleInAir) {
                    mainWindow.showIndicatorDrawer(vtolTransitionIndicatorPage)
                }
            }
        }
    }

    Component {
        id: overallStatusOfflineIndicatorPage

        MainStatusIndicatorOfflinePage {
            Component.onCompleted:   mainWindow.suppressCriticalVehicleMessages = true
            Component.onDestruction: mainWindow.suppressCriticalVehicleMessages = false
        }
    }

    Component {
        id: overallStatusIndicatorPage

        ToolIndicatorPage {
            showExpand:                         true
            waitForParameters:                  false
            expandedComponentWaitForParameters: true
            contentComponent:                   mainStatusContentComponent
            expandedComponent:                  mainStatusExpandedComponent

            Component.onCompleted:   mainWindow.suppressCriticalVehicleMessages = true
            Component.onDestruction: mainWindow.suppressCriticalVehicleMessages = false
        }
    }

    Component {
        id: mainStatusContentComponent

        ColumnLayout {
            id:         mainLayout
            spacing:    _spacing

            property bool parametersReady: QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable

            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth
                visible: parametersReady

                QGCDelayButton {
                    enabled:    _armed || !_healthAndArmingChecksSupported || _activeVehicle.healthAndArmingCheckReport.canArm
                    text:       _armed ? qsTr("锁定") : (control._allowForceArm ? qsTr("强制解锁") : qsTr("解锁"))

                    onActivated: {
                        if (_armed) {
                            _activeVehicle.armed = false
                        } else {
                            if (_allowForceArm) {
                                _allowForceArm = false
                                _activeVehicle.forceArm()
                            } else {
                                _activeVehicle.armed = true
                            }
                        }
                        mainWindow.closeIndicatorDrawer()
                    }
                }

                LabelledComboBox {
                    id:                 primaryLinkCombo
                    Layout.alignment:   Qt.AlignTop
                    label:              qsTr("Primary Link")
                    alternateText:      _primaryLinkName
                    visible:            _activeVehicle && _activeVehicle.vehicleLinkManager.linkNames.length > 1

                    property var    _rgLinkNames:       _activeVehicle ? _activeVehicle.vehicleLinkManager.linkNames : [ ]
                    property var    _rgLinkStatus:      _activeVehicle ? _activeVehicle.vehicleLinkManager.linkStatuses : [ ]
                    property string _primaryLinkName:   _activeVehicle ? _activeVehicle.vehicleLinkManager.primaryLinkName : ""

                    function updateComboModel() {
                        let linkModel = []
                        for (let i = 0; i < _rgLinkNames.length; i++) {
                            let linkStatus = _rgLinkStatus[i]
                            linkModel.push(_rgLinkNames[i] + (linkStatus === "" ? "" : " " + _rgLinkStatus[i]))
                        }
                        primaryLinkCombo.model = linkModel
                        primaryLinkCombo.currentIndex = -1
                    }

                    Component.onCompleted:  updateComboModel()
                    on_RgLinkNamesChanged:  updateComboModel()
                    on_RgLinkStatusChanged: updateComboModel()

                    onActivated:    (index) => {
                        _activeVehicle.vehicleLinkManager.primaryLinkName = _rgLinkNames[index]; currentIndex = -1
                        mainWindow.closeIndicatorDrawer()
                    }
                }
            }

            SettingsGroupLayout {
                //Layout.fillWidth:   true
                heading:            qsTr("Vehicle Messages")

                VehicleMessageList {
                    id: vehicleMessageList
                    objectName: "hdzxVehicleMessagesText"
                    visible: !noMessages
                }

                QGCLabel {
                    text: qsTr("No new vehicle messages")
                    visible: vehicleMessageList.noMessages
                }
            }

            SettingsGroupLayout {
                //Layout.fillWidth:   true
                heading:            qsTr("Sensor Status")
                visible:            parametersReady && !_healthAndArmingChecksSupported

                GridLayout {
                    rowSpacing:     _spacing
                    columnSpacing:  _spacing
                    rows:           _activeVehicle.sysStatusSensorInfo.sensorNames.length
                    flow:           GridLayout.TopToBottom

                    Repeater {
                        model: _activeVehicle.sysStatusSensorInfo.sensorNames
                        QGCLabel { text: modelData }
                    }

                    Repeater {
                        model: _activeVehicle.sysStatusSensorInfo.sensorStatus
                        QGCLabel { text: modelData }
                    }
                }
            }

            SettingsGroupLayout {
                //Layout.fillWidth:   true
                heading:            qsTr("Overall Status")
                visible:            parametersReady && _healthAndArmingChecksSupported && _activeVehicle.healthAndArmingCheckReport.problemsForCurrentMode.count > 0

                // List health and arming checks
                Repeater {
                    model:      _activeVehicle ? _activeVehicle.healthAndArmingCheckReport.problemsForCurrentMode : null
                    delegate:   listdelegate
                }
            }

            Component {
                id: listdelegate

                Column {
                    width: parent ? parent.width : implicitWidth
                    Row {
                        width: parent.width
                        spacing: ScreenTools.defaultFontPixelHeight

                        QGCLabel {
                            id:           message
                            text:         object.message
                            textFormat:   TextEdit.RichText
                            color:        object.severity == 'error' ? qgcPal.colorRed : object.severity == 'warning' ? qgcPal.colorOrange : qgcPal.text
                            width:        parent.width - arrowDownIndicator.width - parent.spacing
                            wrapMode:     Text.Wrap
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (object.description != "")
                                        object.expanded = !object.expanded
                                }
                            }
                        }

                        QGCColoredImage {
                            id:                     arrowDownIndicator
                            anchors.verticalCenter: parent.verticalCenter
                            height:                 1.5 * ScreenTools.defaultFontPixelWidth
                            width:                  height
                            source:                 "/qmlimages/arrow-down.png"
                            color:                  qgcPal.text
                            visible:                object.description != ""
                            MouseArea {
                                anchors.fill:       parent
                                onClicked:          object.expanded = !object.expanded
                            }
                        }
                    }

                    QGCLabel {
                        width:      parent.width
                        visible:    object.translation !== ""
                        text:       object.translation
                        color:      qgcPal.text
                        wrapMode:   Text.Wrap
                    }

                    QGCLabel {
                        width: parent.width
                        visible: object.explanation !== ""
                        text: qsTr("解释：%1").arg(object.explanation)
                        textFormat: Text.PlainText
                        color: qgcPal.text
                        wrapMode: Text.Wrap
                    }

                    QGCLabel {
                        width:      parent.width
                        visible:    object.solution !== ""
                        text:       qsTr("解决方法：%1").arg(object.solution)
                        textFormat: Text.PlainText
                        color:      qgcPal.text
                        wrapMode:   Text.Wrap
                    }

                    QGCLabel {
                        id:                 description
                        text:               object.description
                        textFormat:         TextEdit.RichText
                        clip:               true
                        visible:            object.expanded

                        property var fact:  null

                        onLinkActivated: (link) => {
                            if (link.startsWith('param://')) {
                                var paramName = link.substr(8);
                                fact = controller.getParameterFact(-1, paramName, true)
                                if (fact != null) {
                                    paramEditorDialogFactory.open()
                                }
                            } else {
                                Qt.openUrlExternally(link);
                            }
                        }

                        FactPanelController {
                            id: controller
                        }

                        QGCPopupDialogFactory {
                            id: paramEditorDialogFactory

                            dialogComponent: paramEditorDialogComponent
                        }

                        Component {
                            id: paramEditorDialogComponent

                            ParameterEditorDialog {
                                title:          qsTr("Edit Parameter")
                                fact:           description.fact
                                destroyOnClose: true
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: mainStatusExpandedComponent

        ColumnLayout {
            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 60
            spacing:                margins / 2

            property real margins: ScreenTools.defaultFontPixelHeight

            Loader {
                Layout.fillWidth:   true
                source:             _activeVehicle.expandedToolbarIndicatorSource("MainStatus")
            }

            SettingsGroupLayout {
                Layout.fillWidth:   true
                heading:            qsTr("Force Arm")
                headingDescription: qsTr("Force arming bypasses pre-arm checks. Use with caution.")
                visible:            _activeVehicle && !_armed

                QGCCheckBoxSlider {
                    Layout.fillWidth:   true
                    text:               qsTr("Allow Force Arm")
                    checked:            false
                    onClicked:          _allowForceArm = true
                }
            }

            SettingsGroupLayout {
                Layout.fillWidth:   true
                visible:            QGroundControl.corePlugin.showAdvancedUI

                GridLayout {
                    columns:            2
                    rowSpacing:         ScreenTools.defaultFontPixelHeight / 2
                    columnSpacing:      ScreenTools.defaultFontPixelWidth *2
                    Layout.fillWidth:   true

                    QGCLabel { Layout.fillWidth: true; text: qsTr("Vehicle Parameters") }
                    QGCButton {
                        text: qsTr("Configure")
                        onClicked: {
                            mainWindow.showVehicleConfigParametersPage()
                            mainWindow.closeIndicatorDrawer()
                        }
                    }

                    QGCLabel { Layout.fillWidth: true; text: qsTr("Vehicle Configuration") }
                    QGCButton {
                        text: qsTr("Configure")
                        onClicked: {
                            mainWindow.showVehicleConfig()
                            mainWindow.closeIndicatorDrawer()
                        }
                    }
                }
            }
        }
    }
}
