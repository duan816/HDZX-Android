import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

SetupPage {
    id:             pidTuningPage
    pageComponent:  pidTuningComponent

    Component {
        id: pidTuningComponent

        ColumnLayout {
            width: availableWidth

            FactPanelController { id: controller }

            PIDTuning {
                id: pidTuning
                availableWidth:     pidTuningPage.availableWidth
                availableHeight:    pidTuningPage.availableHeight - pidTuning.y

                property var roll: QtObject {
                    property string name: qsTr("Roll")
                    property var plot: [
                        { name: "Response", value: globals.activeVehicle ? globals.activeVehicle.rollRate.value : NaN },
                        { name: "Setpoint", value: globals.activeVehicle ? globals.activeVehicle.setpoint.rollRate.value : NaN }
                    ]
                    property var params: ListModel {
                        ListElement {
                            title:          qsTr("Roll axis angle controller P gain")
                            param:          "ATC_ANG_RLL_P"
                            description:    ""
                            min:            3
                            max:            12
                            step:           1
                        }
                        ListElement {
                            title:          qsTr("Roll axis rate controller P gain")
                            param:          "ATC_RAT_RLL_P"
                            description:    ""
                            min:            0.001
                            max:            0.5
                            step:           0.025
                        }
                        ListElement {
                            title:          qsTr("Roll axis rate controller I gain")
                            param:          "ATC_RAT_RLL_I"
                            description:    ""
                            min:            0.01
                            max:            2
                            step:           0.05
                        }
                        ListElement {
                            title:          qsTr("Roll axis rate controller D gain")
                            param:          "ATC_RAT_RLL_D"
                            description:    ""
                            min:            0.0
                            max:            0.05
                            step:           0.001
                        }
                    }
                }

                property var pitch: QtObject {
                    property string name: qsTr("Pitch")
                    property var plot: [
                        { name: "Response", value: globals.activeVehicle ? globals.activeVehicle.pitchRate.value : NaN },
                        { name: "Setpoint", value: globals.activeVehicle ? globals.activeVehicle.setpoint.pitchRate.value : NaN }
                    ]
                    property var params: ListModel {
                        ListElement {
                            title:          qsTr("Pitch axis angle controller P gain")
                            param:          "ATC_ANG_PIT_P"
                            description:    ""
                            min:            3
                            max:            12
                            step:           1
                        }
                        ListElement {
                            title:          qsTr("Pitch axis rate controller P gain")
                            param:          "ATC_RAT_PIT_P"
                            description:    ""
                            min:            0.001
                            max:            0.5
                            step:           0.025
                        }
                        ListElement {
                            title:          qsTr("Pitch axis rate controller I gain")
                            param:          "ATC_RAT_PIT_I"
                            description:    ""
                            min:            0.01
                            max:            2
                            step:           0.05
                        }
                        ListElement {
                            title:          qsTr("Pitch axis rate controller D gain")
                            param:          "ATC_RAT_PIT_D"
                            description:    ""
                            min:            0.0
                            max:            0.05
                            step:           0.001
                        }
                    }
                }

                property var yaw: QtObject {
                    property string name: qsTr("Yaw")
                    property var plot: [
                        { name: "Response", value: globals.activeVehicle ? globals.activeVehicle.yawRate.value : NaN },
                        { name: "Setpoint", value: globals.activeVehicle ? globals.activeVehicle.setpoint.yawRate.value : NaN }
                    ]
                    property var params: ListModel {
                        ListElement {
                            title:          qsTr("Yaw axis angle controller P gain")
                            param:          "ATC_ANG_YAW_P"
                            description:    ""
                            min:            3
                            max:            12
                            step:           1
                        }
                        ListElement {
                            title:          qsTr("Yaw axis rate controller P gain")
                            param:          "ATC_RAT_YAW_P"
                            description:    ""
                            min:            0.1
                            max:            2.5
                            step:           0.05
                        }
                        ListElement {
                            title:          qsTr("Yaw axis rate controller I gain")
                            param:          "ATC_RAT_YAW_I"
                            description:    ""
                            min:            0.01
                            max:            1
                            step:           0.05
                        }
                    }
                }

                title:          "Rate"
                tuningMode:     Vehicle.ModeRateAndAttitude
                unit:           "deg/s"
                axis:           [ roll, pitch, yaw ]
                chartDisplaySec: 3
            }
        }
    }
}
