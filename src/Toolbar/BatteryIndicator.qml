import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import "HQIndicatorMath.js" as IndicatorMath

//-------------------------------------------------------------------------
//-- Battery Indicator
Item {
    id:             control
    objectName:     "toolbar_batteryIndicator"
    anchors.top:    parent.top
    anchors.bottom: parent.bottom
    width:          batteryIndicatorRow.width

    property bool       showIndicator:      _activeVehicle && _activeVehicle.batteries.count > 0
    property bool       waitForParameters:  false
    property Component  expandedPageComponent

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property var    _batterySettings:   QGroundControl.settingsManager.batteryIndicatorSettings
    property Fact   _indicatorDisplay:  _batterySettings.valueDisplay
    property bool   _showPercentage:    _indicatorDisplay.rawValue === 0
    property bool   _showVoltage:       _indicatorDisplay.rawValue === 1
    property bool   _showBoth:          _indicatorDisplay.rawValue === 2
    property int    _lowestBatteryId:   -1      // -1: show all batteries, otherwise show only battery with this id

    // Properties to hold the thresholds
    property int threshold1: _batterySettings.threshold1.rawValue
    property int threshold2: _batterySettings.threshold2.rawValue
    RCChannelMonitorController { id: batteryParameters }

    function voltageParameter(name) {
        // This controller follows active-vehicle changes; reading its notifier
        // also refreshes parameter bindings for cached, already-ready vehicles.
        const channelRevision = batteryParameters.channelCount
        if (!_activeVehicle || !_activeVehicle.parameterManager.parametersReady || !name
                || batteryParameters.vehicle !== _activeVehicle) return null
        return batteryParameters.parameterExists(-1, name) ? batteryParameters.getParameterFact(-1, name, false) : null
    }

    function _recalcLowestBatteryIdFromVoltage() {
        if (_activeVehicle) {
            // If there is only one battery then it is the lowest
            if (_activeVehicle.batteries.count === 1) {
                _lowestBatteryId = _activeVehicle.batteries.get(0).id.rawValue
                return
            }

            // If we have valid voltage for all batteries we use that to determine lowest battery
            let allHaveVoltage = true
            for (var i = 0; i < _activeVehicle.batteries.count; i++) {
                let battery = _activeVehicle.batteries.get(i)
                if (isNaN(battery.voltage.rawValue)) {
                    allHaveVoltage = false
                    break
                }
            }
            if (allHaveVoltage) {
                let lowestBattery = _activeVehicle.batteries.get(0)
                let lowestBatteryId = lowestBattery.id.rawValue
                for (var i = 1; i < _activeVehicle.batteries.count; i++) {
                    let battery = _activeVehicle.batteries.get(i)
                    if (battery.voltage.rawValue < lowestBattery.voltage.rawValue) {
                        lowestBattery = battery
                        lowestBatteryId = battery.id.rawValue
                    }
                }
                _lowestBatteryId = lowestBatteryId
                return
            }
        }

        // Couldn't determine lowest battery, show all
        _lowestBatteryId = -1
    }

    function _recalcLowestBatteryIdFromPercentage() {
        if (_activeVehicle) {
            // If there is only one battery then it is the lowest
            if (_activeVehicle.batteries.count === 1) {
                _lowestBatteryId = _activeVehicle.batteries.get(0).id.rawValue
                return
            }

            // If we have valid percentage for all batteries we use that to determine lowest battery
            let allHavePercentage = true
            for (var i = 0; i < _activeVehicle.batteries.count; i++) {
                let battery = _activeVehicle.batteries.get(i)
                if (isNaN(battery.percentRemaining.rawValue)) {
                    allHavePercentage = false
                    break
                }
            }
            if (allHavePercentage) {
                let lowestBattery = _activeVehicle.batteries.get(0)
                let lowestBatteryId = lowestBattery.id.rawValue
                for (var i = 1; i < _activeVehicle.batteries.count; i++) {
                    let battery = _activeVehicle.batteries.get(i)
                    if (battery.percentRemaining.rawValue < lowestBattery.percentRemaining.rawValue) {
                        lowestBattery = battery
                        lowestBatteryId = battery.id.rawValue
                    }
                }
                _lowestBatteryId = lowestBatteryId
                return
            }
        }

        // Couldn't determine lowest battery, show all
        _lowestBatteryId = -1
    }

    function _recalcLowestBatteryIdFromChargeState() {
        if (_activeVehicle) {
            // If there is only one battery then it is the lowest
            if (_activeVehicle.batteries.count === 1) {
                _lowestBatteryId = _activeVehicle.batteries.get(0).id.rawValue
                return
            }

            // If we have valid chargeState for all batteries we use that to determine lowest battery
            let allHaveChargeState = true
            for (var i = 0; i < _activeVehicle.batteries.count; i++) {
                let battery = _activeVehicle.batteries.get(i)
                if (battery.chargeState.rawValue === MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_UNDEFINED) {
                    allHaveChargeState = false
                    break
                }
            }
            if (allHaveChargeState) {
                let lowestBattery = _activeVehicle.batteries.get(0)
                let lowestBatteryId = lowestBattery.id.rawValue
                for (var i = 1; i < _activeVehicle.batteries.count; i++) {
                    let battery = _activeVehicle.batteries.get(i)
                    if (battery.chargeState.rawValue > lowestBattery.chargeState.rawValue) {
                        lowestBattery = battery
                        lowestBatteryId = battery.id.rawValue
                    }
                }
                _lowestBatteryId = lowestBatteryId
                return
            }
        }

        // Couldn't determine lowest battery, show all
        _lowestBatteryId = -1
    }

    function _recalcLowestBatteryId() {
        if (!_activeVehicle || _activeVehicle.batteries.count === 0) {
            _lowestBatteryId = -1
            return
        }
        if (_batterySettings.valueDisplay.rawValue === 0) {
            // User wants percentage display so use that if available
            _recalcLowestBatteryIdFromPercentage()
        } else if (_batterySettings.valueDisplay.rawValue === 1) {
            // User wants voltage display so use that if available
            _recalcLowestBatteryIdFromVoltage()
        }
        // If we still dont have a lowest battery id then try charge state
        if (_lowestBatteryId === -1) {
            _recalcLowestBatteryIdFromChargeState()
        }
    }

    Component.onCompleted: _recalcLowestBatteryId()

    Connections {
        target: _activeVehicle ? _activeVehicle.batteries : null
        function onCountChanged() {_recalcLowestBatteryId() }
    }

    QGCPalette { id: qgcPal }

    RowLayout {
        id:             batteryIndicatorRow
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        spacing:        ScreenTools.defaultFontPixelWidth / 2

        Repeater {
            model: _activeVehicle ? _activeVehicle.batteries : 0

            Loader {
                Layout.fillHeight:  true
                sourceComponent:    batteryVisual
                visible:            control._lowestBatteryId === -1 || object.id.rawValue === control._lowestBatteryId || !control._batterySettings.consolidateMultipleBatteries.rawValue

                property var battery: object
            }
        }
    }

    MouseArea {
        anchors.fill:   parent
        onClicked:      mainWindow.showIndicatorDrawer(batteryPopup, control)
    }

    Component {
        id: batteryPopup

        ToolIndicatorPage {
            showExpand:         expandedComponent ? true : false
            waitForParameters:                  false
            expandedComponentWaitForParameters: true
            contentComponent:   batteryContentComponent
            expandedComponent:  batteryExpandedComponent
        }
    }

    Component {
        id: batteryVisual

        Row {
            id: batteryRow
            Layout.fillHeight:  true
            spacing:            ScreenTools.defaultFontPixelWidth / 4
            readonly property var voltageNames: _activeVehicle ? _activeVehicle.batteryIndicatorVoltageParameters(Number(battery.id.rawValue)) : []
            readonly property Fact fullFact: control.voltageParameter(voltageNames.length > 0 ? voltageNames[0] : "")
            readonly property Fact lowFact: control.voltageParameter(voltageNames.length > 1 ? voltageNames[1] : "")
            readonly property Fact cellsFact: control.voltageParameter(voltageNames.length > 2 ? voltageNames[2] : "")
            readonly property real cells: voltageNames.length > 2 && voltageNames[2] ? (cellsFact ? Number(cellsFact.rawValue) : NaN) : 1
            readonly property real fullVoltage: Number(battery.id.rawValue) === 0 && _batterySettings.ringFullVoltage.rawValue > 0
                                               ? Number(_batterySettings.ringFullVoltage.rawValue) : (fullFact ? Number(fullFact.rawValue) * cells : NaN)
            readonly property real lowVoltage: Number(battery.id.rawValue) === 0 && _batterySettings.ringLowVoltage.rawValue > 0
                                              ? Number(_batterySettings.ringLowVoltage.rawValue) : (lowFact ? Number(lowFact.rawValue) * cells : NaN)
            readonly property real voltageFraction: IndicatorMath.voltageFraction(Number(battery.voltage.rawValue), lowVoltage, fullVoltage)
            readonly property bool voltageBased: isFinite(voltageFraction)
            readonly property real ringFraction: voltageBased ? voltageFraction : IndicatorMath.percentageFraction(Number(battery.percentRemaining.rawValue))
            readonly property bool linkLost: !_activeVehicle || _activeVehicle.vehicleLinkManager.communicationLost
            readonly property bool lowVoltageReached: voltageBased && Number(battery.voltage.rawValue) <= lowVoltage
            readonly property bool criticalBattery: lowVoltageReached || battery.chargeState.rawValue === MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_CRITICAL
                                                   || battery.chargeState.rawValue === MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_EMERGENCY
                                                   || battery.chargeState.rawValue === MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_FAILED
                                                   || battery.chargeState.rawValue === MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_UNHEALTHY

            HQCircularGauge {
                width: batteryRow.height * 0.94
                height: width
                anchors.verticalCenter: parent.verticalCenter
                fraction: batteryRow.linkLost ? NaN : batteryRow.ringFraction
                valueText: Math.round(batteryRow.ringFraction * 100) + "%"
                caption: batteryRow.voltageBased ? qsTr("电压") : qsTr("电量")
                critical: batteryRow.criticalBattery
                accentColor: critical ? qgcPal.colorRed : battery.chargeState.rawValue === MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_LOW
                             || fraction <= 0.2 ? qgcPal.colorOrange : fraction <= 0.4 ? qgcPal.colorYellow : qgcPal.colorGreen
            }

            function getBatteryColor() {
                switch (battery.chargeState.rawValue) {
                    case MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_OK:
                        if (!isNaN(battery.percentRemaining.rawValue)) {
                            if (battery.percentRemaining.rawValue > threshold1) {
                                return qgcPal.colorGreen
                            } else if (battery.percentRemaining.rawValue > threshold2) {
                                return qgcPal.colorYellowGreen
                            } else {
                                return qgcPal.colorYellow
                            }
                        } else {
                            return qgcPal.text
                        }
                    case MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_LOW:
                        return qgcPal.colorOrange
                    case MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_CRITICAL:
                    case MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_EMERGENCY:
                    case MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_FAILED:
                    case MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_UNHEALTHY:
                        return qgcPal.colorRed
                    default:
                        return qgcPal.text
                }
            }

            function getBatterySvgSource() {
                switch (battery.chargeState.rawValue) {
                    case MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_OK:
                        if (!isNaN(battery.percentRemaining.rawValue)) {
                            if (battery.percentRemaining.rawValue > threshold1) {
                                return "/qmlimages/BatteryGreen.svg"
                            } else if (battery.percentRemaining.rawValue > threshold2) {
                                return "/qmlimages/BatteryYellowGreen.svg"
                            } else {
                                return "/qmlimages/BatteryYellow.svg"
                            }
                        }
                    case MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_LOW:
                        return "/qmlimages/BatteryOrange.svg" // Low with orange svg
                    case MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_CRITICAL:
                        return "/qmlimages/BatteryCritical.svg" // Critical with red svg
                    case MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_EMERGENCY:
                    case MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_FAILED:
                    case MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_UNHEALTHY:
                        return "/qmlimages/BatteryEMERGENCY.svg" // Exclamation mark
                    default:
                        return "/qmlimages/Battery.svg" // Fallback if percentage is unavailable
                }
            }

            function getBatteryPercentageText() {
                if (!isNaN(battery.percentRemaining.rawValue)) {
                    if (battery.percentRemaining.rawValue > 98.9) {
                        return qsTr("100%")
                    } else {
                        return battery.percentRemaining.valueString + battery.percentRemaining.units
                    }
                } else if (!isNaN(battery.voltage.rawValue)) {
                    return battery.voltage.valueString + battery.voltage.units
                } else if (battery.chargeState.rawValue !== MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_UNDEFINED) {
                    return battery.chargeState.enumStringValue
                }
                return qsTr("n/a")
            }

            function getBatteryVoltageText() {
                if (!isNaN(battery.voltage.rawValue)) {
                    return battery.voltage.valueString + battery.voltage.units
                } else if (battery.chargeState.rawValue !== MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_UNDEFINED) {
                    return battery.chargeState.enumStringValue
                }
                return qsTr("n/a")
            }

            Timer {
                id:         debounceRecalcTimer
                interval:   50
                running:    false
                repeat:     false
                onTriggered: {
                    control._recalcLowestBatteryId()
                }
            }
            Connections {
                target: battery.percentRemaining
                function onRawValueChanged() {
                    debounceRecalcTimer.restart()
                }
            }
            Connections {
                target: battery.voltage
                function onRawValueChanged() {
                    debounceRecalcTimer.restart()
                }
            }
            Connections {
                target: battery.chargeState
                function onRawValueChanged() {
                    debounceRecalcTimer.restart()
                }
            }

            QGCColoredImage {
                anchors.verticalCenter: parent.verticalCenter
                height:             batteryRow.height * 0.52
                width:              height
                sourceSize.width:   width
                source:             getBatterySvgSource()
                fillMode:           Image.PreserveAspectFit
                color:              getBatteryColor()
            }

           ColumnLayout {
                id:                     batteryInfoColumn
                anchors.top:            parent.top
                anchors.bottom:         parent.bottom
                spacing:                0

                QGCLabel {
                    Layout.alignment:       Qt.AlignHCenter
                    verticalAlignment:      Text.AlignVCenter
                    color:                  qgcPal.text
                    text:                   getBatteryPercentageText()
                    font.pointSize:         _showBoth ? ScreenTools.defaultFontPointSize : ScreenTools.mediumFontPointSize
                    visible:                _showBoth || _showPercentage
                }

                QGCLabel {
                    Layout.alignment:       Qt.AlignHCenter
                    font.pointSize:         _showBoth ? ScreenTools.defaultFontPointSize : ScreenTools.mediumFontPointSize
                    color:                  qgcPal.text
                    text:                   getBatteryVoltageText()
                    visible:                _showBoth || _showVoltage
                }
            }
        }
    }

    Component {
        id: batteryContentComponent

        ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight / 2

            Component {
                id: batteryValuesAvailableComponent

                QtObject {
                    property bool functionAvailable:         battery.function.rawValue !== MAVLinkEnums.MAV_BATTERY_FUNCTION_UNKNOWN
                    property bool showFunction:              functionAvailable && battery.function.rawValue != MAVLinkEnums.MAV_BATTERY_FUNCTION_ALL
                    property bool temperatureAvailable:      !isNaN(battery.temperature.rawValue)
                    property bool currentAvailable:          !isNaN(battery.current.rawValue)
                    property bool mahConsumedAvailable:      !isNaN(battery.mahConsumed.rawValue)
                    property bool timeRemainingAvailable:    !isNaN(battery.timeRemaining.rawValue)
                    property bool percentRemainingAvailable: !isNaN(battery.percentRemaining.rawValue)
                    property bool chargeStateAvailable:      battery.chargeState.rawValue !== MAVLinkEnums.MAV_BATTERY_CHARGE_STATE_UNDEFINED
                }
            }

            Repeater {
                model: _activeVehicle ? _activeVehicle.batteries : 0

                SettingsGroupLayout {
                    heading:        qsTr("Battery %1").arg(_activeVehicle.batteries.length === 1 ? qsTr("Status") : object.id.rawValue)
                    contentSpacing: 0
                    showDividers:   false

                    property var batteryValuesAvailable: batteryValuesAvailableLoader.item

                    Loader {
                        id:                 batteryValuesAvailableLoader
                        sourceComponent:    batteryValuesAvailableComponent

                        property var battery: object
                    }

                    LabelledLabel {
                        label:  qsTr("Charge State")
                        labelText:  object.chargeState.enumStringValue
                        visible:    batteryValuesAvailable.chargeStateAvailable
                    }

                    LabelledLabel {
                        label:      qsTr("Remaining")
                        labelText:  object.timeRemainingStr.value
                        visible:    batteryValuesAvailable.timeRemainingAvailable
                    }

                    LabelledLabel {
                        label:      qsTr("Remaining")
                        labelText:  object.percentRemaining.valueString + " " + object.percentRemaining.units
                        visible:    batteryValuesAvailable.percentRemainingAvailable
                    }

                    LabelledLabel {
                        label:      qsTr("Voltage")
                        labelText:  object.voltage.valueString + " " + object.voltage.units
                    }

                    LabelledLabel {
                        label:      qsTr("Consumed")
                        labelText:  object.mahConsumed.valueString + " " + object.mahConsumed.units
                        visible:    batteryValuesAvailable.mahConsumedAvailable
                    }

                    LabelledLabel {
                        label:      qsTr("Temperature")
                        labelText:  object.temperature.valueString + " " + object.temperature.units
                        visible:    batteryValuesAvailable.temperatureAvailable
                    }

                    LabelledLabel {
                        label:      qsTr("Function")
                        labelText:  object.function.enumStringValue
                        visible:    batteryValuesAvailable.showFunction
                    }
                }
            }
        }
    }

    Component {
        id: batteryExpandedComponent

        ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight / 2

            property real batteryIconHeight: ScreenTools.defaultFontPixelWidth * 3

            FactPanelController { id: controller }

            SettingsGroupLayout {
                heading:            qsTr("Battery Display")
                Layout.fillWidth:   true

                FactCheckBoxSlider {
                    Layout.fillWidth:   true
                    fact:               _batterySettings.consolidateMultipleBatteries
                    text:               qsTr("Only show battery with lowest charge")
                    visible:            fact.userVisible
                }

                LabelledFactComboBox {
                    label:      qsTr("Value")
                    fact:       _batterySettings.valueDisplay
                    visible:    fact.userVisible
                }

                ColumnLayout {
                    QGCLabel { text: qsTr("Coloring") }

                    RowLayout {
                        spacing: ScreenTools.defaultFontPixelWidth

                        // Battery 100%
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 0.05  // Tighter spacing for icon and label
                            QGCColoredImage {
                                source: "/qmlimages/BatteryGreen.svg"
                                width: height
                                height: batteryIconHeight
                                fillMode: Image.PreserveAspectFit
                                color: qgcPal.colorGreen
                            }
                            QGCLabel { text: qsTr("100%") }
                        }

                        // Threshold 1
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 0.05  // Tighter spacing for icon and field
                            QGCColoredImage {
                                source: "/qmlimages/BatteryYellowGreen.svg"
                                width: height
                                height: batteryIconHeight
                                fillMode: Image.PreserveAspectFit
                                color: qgcPal.colorYellowGreen
                            }
                            FactTextField {
                                id: threshold1Field
                                fact: _batterySettings.threshold1
                                implicitWidth: ScreenTools.defaultFontPixelWidth * 6
                                height: ScreenTools.defaultFontPixelHeight * 1.5
                                enabled: fact.userVisible
                                onEditingFinished: {
                                    // Validate and set the new threshold value
                                    _batterySettings.setThreshold1(parseInt(text));
                                }
                            }
                        }

                        // Threshold 2
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 0.05  // Tighter spacing for icon and field
                            QGCColoredImage {
                                source: "/qmlimages/BatteryYellow.svg"
                                width: height
                                height: batteryIconHeight
                                fillMode: Image.PreserveAspectFit
                                color: qgcPal.colorYellow
                            }
                            FactTextField {
                                fact: _batterySettings.threshold2
                                implicitWidth: ScreenTools.defaultFontPixelWidth * 6
                                height: ScreenTools.defaultFontPixelHeight * 1.5
                                enabled: fact.userVisible
                                onEditingFinished: {
                                    // Validate and set the new threshold value
                                    _batterySettings.setThreshold2(parseInt(text));
                                }
                            }
                        }

                        // Low state
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 0.05  // Tighter spacing for icon and label
                            QGCColoredImage {
                                source: "/qmlimages/BatteryOrange.svg"
                                width: height
                                height: batteryIconHeight
                                fillMode: Image.PreserveAspectFit
                                color: qgcPal.colorOrange
                            }
                            QGCLabel { text: qsTr("Low") }
                        }

                        // Critical state
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 0.05  // Tighter spacing for icon and label
                            QGCColoredImage {
                                source: "/qmlimages/BatteryCritical.svg"
                                width: height
                                height: batteryIconHeight
                                fillMode: Image.PreserveAspectFit
                                color: qgcPal.colorRed
                            }
                            QGCLabel { text: qsTr("Critical") }
                        }
                    }
                }
            }

            SettingsGroupLayout {
                heading: qsTr("电池 1 圆环电压范围（整包电压）")
                LabelledFactTextField { label: qsTr("满电电压："); fact: _batterySettings.ringFullVoltage }
                LabelledFactTextField { label: qsTr("低电电压："); fact: _batterySettings.ringLowVoltage }
                QGCLabel {
                    Layout.fillWidth: true
                    Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 48
                    text: qsTr("0 表示使用飞控已有设置。AP 没有通用满电电压参数，请设置满电电压；低电压可读取 BATT_LOW_VOLT。PX4 自动读取单节电压与电池节数。没有有效电压范围时显示飞控上报电量。电压余量仅供参考，负载压降会影响结果；这里的设置仅影响显示，不修改飞控失控保护参数。")
                    wrapMode: Text.WordWrap
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                QGCLabel {
                    visible: _batterySettings.ringFullVoltage.rawValue > 0 && _batterySettings.ringLowVoltage.rawValue > 0
                             && _batterySettings.ringFullVoltage.rawValue <= _batterySettings.ringLowVoltage.rawValue
                    text: qsTr("满电电压必须高于低电电压，当前将使用飞控电量显示。")
                    color: qgcPal.colorOrange
                }
            }

            Loader {
                Layout.fillWidth:   true
                source:             _activeVehicle.expandedToolbarIndicatorSource("Battery")
            }

            SettingsGroupLayout {
                visible: _activeVehicle.autopilotPlugin.knownVehicleComponentAvailable(AutoPilotPlugin.KnownPowerVehicleComponent) &&
                            QGroundControl.corePlugin.showAdvancedUI

                LabelledButton {
                    label:      qsTr("Vehicle Power")
                    buttonText: qsTr("Configure")

                    onClicked: {
                        mainWindow.showKnownVehicleComponentConfigPage(AutoPilotPlugin.KnownPowerVehicleComponent)
                        mainWindow.closeIndicatorDrawer()
                    }
                }
            }
        }
    }
}
