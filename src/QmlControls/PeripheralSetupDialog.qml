pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import "PeripheralProfiles.js" as PeripheralProfiles

QGCPopupDialog {
    id: root

    required property var controller
    required property var vehicle

    title: qsTr("外设配置建议（Peripheral Setup Assistant）")
    buttons: Dialog.Cancel | Dialog.Apply
    acceptButtonEnabled: root.canApply
    property bool connected: !!vehicle && !!vehicle.vehicleLinkManager && !vehicle.vehicleLinkManager.communicationLost
    property bool canApply: !guideOnly && connected && vehicle === controller.vehicle && vehicle === QGroundControl.multiVehicleManager.activeVehicle && !vehicle.armed && !vehicle.flying && root.writableCount > 0 && root.blockedCount === 0 && !root.portConflict && root.firmwareSupported && (!verificationRequired || firmwareConfirmed.checked) && (root.selectedProfile().kind !== "flow" || flowMountConfirmed.checked) && (!root.powerProfile || powerConfirmed.checked)
    readonly property bool guideOnly: !!selectedProfile().guideOnly
    readonly property bool verificationRequired: !!selectedProfile().requiresVerification
    readonly property bool installationRange: selectedProfile().kind === "flow-can" || selectedProfile().variant === "micovio"
    readonly property bool modernMavOptions: !!vehicle && vehicle.apmFirmware && (controller.parameterExists(-1, "MAV0_OPTIONS") || controller.parameterExists(-1, "MAV1_OPTIONS") || controller.parameterExists(-1, "MAV_0_OPTIONS") || (vehicle.firmwareMajorVersion === 4 && vehicle.firmwareMinorVersion >= 7))
    readonly property bool needsMavChannel: modernMavOptions && (selectedProfile().kind === "flow" || selectedProfile().variant === "micovio")
    readonly property var guidance: PeripheralProfiles.guidance(selectedProfile(), vehicle && vehicle.apmFirmware ? "ap" : vehicle && vehicle.px4Firmware ? "px4" : "")
    readonly property bool firmwareSupported: selectedProfile().kind !== "power-i2c" || (vehicle && vehicle.apmFirmware && (vehicle.firmwareMajorVersion > 4 || (vehicle.firmwareMajorVersion === 4 && vehicle.firmwareMinorVersion >= 4)))
    readonly property bool powerProfile: PeripheralProfiles.isPower(selectedProfile())
    readonly property bool rangeProfile: PeripheralProfiles.isRange(selectedProfile())
    readonly property bool elrsProfile: PeripheralProfiles.isElrs(selectedProfile())
    readonly property bool i2cProfile: selectedProfile().kind === "range-i2c"
    readonly property var shownProfiles: profiles.filter(profile => PeripheralProfiles.category(profile) === PeripheralProfiles.categories[Math.max(0, categoryCombo.currentIndex)].key)
    readonly property bool canProfile: selectedProfile().kind === "can" || selectedProfile().kind === "power-can" || selectedProfile().kind === "flow-can"
    property bool portConflict: {
        selectionRevision
        if (!vehicle || guideOnly) return false
        if (vehicle.apmFirmware && root.installationRange) {
            var existingRange = findFact(["RNGFND" + (rangeCombo.currentIndex + 1) + "_TYPE"])
            var expectedRange = selectedProfile().kind === "flow-can" ? 24 : 10
            if (existingRange && ![0, expectedRange].includes(Number(existingRange.rawValue))) return true
        }
        if (vehicle.apmFirmware && (selectedProfile().kind === "flow-uart" || selectedProfile().kind === "vio")) {
            var existingSerial = findFact([portCombo.currentText + "_PROTOCOL"])
            var expectedSerial = selectedProfile().kind === "flow-uart" ? 18 : 2
            if (existingSerial && ![-1, 0, expectedSerial].includes(Number(existingSerial.rawValue))) return true
        }
        if (vehicle.apmFirmware && (root.rangeProfile || root.elrsProfile)) {
            if (root.rangeProfile) {
                var installed = findFact(["RNGFND" + (rangeCombo.currentIndex + 1) + "_TYPE"])
                if (installed && Number(installed.rawValue) !== 0 && Number(installed.rawValue) !== selectedProfile().apType) return true
            }
            if (!root.i2cProfile) {
                var assigned = findFact([portCombo.currentText + "_PROTOCOL"])
                var compatible = root.rangeProfile ? 9 : selectedProfile().kind === "elrs-crsf" ? 23 : 2
                if (assigned && ![-1, 0, compatible].includes(Number(assigned.rawValue))) return true
                if (compatible === 2 && assigned && Number(assigned.rawValue) === 2) {
                    var existingBaud = findFact([portCombo.currentText + "_BAUD"])
                    if (!existingBaud || Number(existingBaud.rawValue) !== 460) return true
                }
                if (root.rangeProfile) {
                    // ArduPilot pairs serial range drivers with protocol-9 UARTs in order.
                    // Do not silently attach another installed rangefinder to the wrong driver.
                    var serialTypes = [8, 19, 20, 26, 27]
                    var expectedIndex = 0, sensorCount = 1, portIndex = 0, portCount = 1
                    for (var instance = 1; instance <= 4; ++instance) {
                        if (instance === rangeCombo.currentIndex + 1) continue
                        var sensor = findFact(["RNGFND" + instance + "_TYPE"])
                        var type = sensor ? Number(sensor.rawValue) : 0
                        if (serialTypes.includes(type)) {
                            ++sensorCount
                            if (instance < rangeCombo.currentIndex + 1) ++expectedIndex
                        } else if (![0, 15, 25].includes(type)) return true
                    }
                    for (var number = 1; number <= 8; ++number) {
                        if (number === portCombo.currentIndex + 1) continue
                        var otherPort = findFact(["SERIAL" + number + "_PROTOCOL"])
                        if (otherPort && Number(otherPort.rawValue) === 9) {
                            ++portCount
                            if (number < portCombo.currentIndex + 1) ++portIndex
                        }
                    }
                    if (expectedIndex !== portIndex || sensorCount !== portCount) return true
                }
            }
        }
        if (vehicle.apmFirmware && root.canProfile) {
            var physical = portCombo.currentText === "CAN2" ? 2 : 1
            var binding = findFact(["CAN_P" + physical + "_DRIVER"])
            var protocol = binding && Number(binding.rawValue) > 0 ? findFact(["CAN_D" + Number(binding.rawValue) + "_PROTOCOL"]) : null
            return !!protocol && Number(protocol.rawValue) !== 1
        }
        if (!vehicle.px4Firmware || root.canProfile || root.powerProfile || root.i2cProfile) return false
        if (["flow", "vio", "telemetry", "elrs-mavlink"].includes(selectedProfile().kind)) {
            var flowChannel = findFact(["MAV_1_CONFIG"])
            if (flowChannel && Number(flowChannel.rawValue) !== 0) return true
        }
        var port = PeripheralProfiles.px4Ports[portCombo.currentText]
        // Never repurpose an active PX4 MAVLink interface as a sensor port implicitly.
        for (var i = 0; i < 3; ++i) {
            var fact = findFact(["MAV_" + i + "_CONFIG"])
            if (fact && Number(fact.rawValue) === port) return true
        }
        if (root.elrsProfile || root.rangeProfile || selectedProfile().kind === "flow-uart" || selectedProfile().kind === "vio") {
            var ownDriver = selectedProfile().kind === "elrs-crsf" ? "RC_CRSF_PRT_CFG"
                            : root.rangeProfile ? (selectedProfile().px4Config || "SENS_TFMINI_CFG") : selectedProfile().kind === "flow-uart" ? "SENS_TFLOW_CFG" : ""
            var drivers = ["GPS_1_CONFIG", "GPS_2_CONFIG", "SEP_PORT1_CFG", "SEP_PORT2_CFG",
                           "RC_CRSF_PRT_CFG", "SENS_TFMINI_CFG", "SENS_SF0X_CFG", "SENS_CM8JL65_CFG", "SENS_TFLOW_CFG"]
            for (var driver of drivers) {
                var configured = findFact([driver])
                if (driver !== ownDriver && configured && Number(configured.rawValue) === port) return true
            }
        }
        return false
    }
    property int blockedCount: suggestions.filter(function(item) { return !item.noWrite && !item.optional && (!item.fact || item.fact.readOnly || !item.valid) }).length

    property int selectionRevision: 0
    property bool _componentReady: false
    Component.onCompleted: _componentReady = true
    onVehicleChanged: if (_componentReady) firmwareConfirmed.checked = false
    onConnectedChanged: if (_componentReady && !connected) firmwareConfirmed.checked = false
    property var profiles: PeripheralProfiles.profiles
    property var suggestions: {
        selectionRevision
        return buildSuggestions()
    }
    property int writableCount: {
        var count = 0
        for (var i = 0; i < suggestions.length; ++i) {
            if (!suggestions[i].noWrite && suggestions[i].fact && !suggestions[i].fact.readOnly && suggestions[i].valid) {
                ++count
            }
        }
        return count
    }

    function selectedProfile() {
        return shownProfiles[Math.max(0, deviceCombo.currentIndex)] || profiles[0]
    }

    function updateDeviceSelection() {
        portCombo.model = root.portOptions()
        portCombo.currentIndex = 0
        baudCombo.currentIndex = Math.max(0, baudCombo.model.indexOf(String(root.selectedProfile().baud || 115200)))
        flowMountConfirmed.checked = false
        powerConfirmed.checked = false
        firmwareConfirmed.checked = false
        mavChannel.currentIndex = 0
        flowFusion.checked = false
        flowProtocol.checked = false
        ++selectionRevision
    }

    function portOptions() {
        if (root.canProfile) {
            return ["CAN1", "CAN2"]
        }
        if (root.powerProfile || root.i2cProfile) return ["POWER / I²C"]
        if (vehicle && vehicle.apmFirmware) {
            return ["SERIAL1", "SERIAL2", "SERIAL3", "SERIAL4", "SERIAL5", "SERIAL6", "SERIAL7", "SERIAL8"]
        }
        return ["GPS1", "GPS2", "TELEM1", "TELEM2", "TELEM3", "TELEM/SERIAL4", "UART6"]
    }

    function findFact(names) {
        for (var i = 0; i < names.length; ++i) {
            if (controller.parameterExists(-1, names[i])) {
                return controller.getParameterFact(-1, names[i], false)
            }
        }
        return null
    }

    function factDisplay(fact) {
        if (!fact) {
            return qsTr("当前固件无此参数")
        }
        if (fact.enumStrings && fact.enumStrings.length > 0) {
            return "%1（%2）".arg(fact.rawValue).arg(fact.enumStringValue)
        }
        return String(fact.rawValue)
    }

    function suggestion(row) {
        var fact = findFact(row.names)
        var value = row.orMask && fact ? Number(fact.rawValue) | row.orMask : row.value
        if (row.preserveZero && fact && Number(fact.rawValue) === 0) value = 0
        if (row.clearMask && fact) value = Number(fact.rawValue) & ~row.clearMask
        if (row.minimumValue && fact) value = Math.max(value, Number(fact.rawValue))
        if (row.centimeterAlias && fact && fact.name.endsWith("_CM")) value *= 100
        if (row.keepCurrent && fact) value = Number(fact.rawValue)
        var noWrite = !!row.manual || !!row.keepCurrent
        var valid = Number.isFinite(value)
        if (fact && row.orMask && fact.bitmaskValues && fact.bitmaskValues.length) {
            var supportedBits = fact.bitmaskValues.reduce(function(bits, entry) { return bits | Number(entry) }, 0)
            valid = (supportedBits & row.orMask) === row.orMask
        }
        if (fact && fact.enumValues && fact.enumValues.length && !row.orMask) {
            valid = fact.enumValues.some(function(entry) { return Number(entry) === value })
        }
        if (valid && !noWrite && fact && typeof fact.validate === "function") valid = fact.validate(String(value), false).length === 0
        return {
            names: row.names,
            name: fact ? fact.name : row.names[0],
            fact: fact,
            value: value,
            optional: row.optional,
            valid: valid,
            noWrite: noWrite,
            manual: !!row.manual,
            current: factDisplay(fact),
            recommended: row.manual ? qsTr("需实测") : row.keepCurrent ? (isFinite(value) ? String(value) : "--") : String(value),
            note: row.note + (row.optional && !noWrite ? qsTr("（可选；不支持时跳过）") : "") + (!valid && !noWrite ? qsTr("（当前固件不支持该数值，禁止应用）") : "")
        }
    }

    function buildSuggestions() {
        if (!vehicle || !controller || deviceCombo.currentIndex < 0) {
            return []
        }

        var profile = selectedProfile()
        var firmware = vehicle.apmFirmware ? "ap" : vehicle.px4Firmware ? "px4" : ""
        var instance = root.powerProfile ? batteryCombo.currentIndex + 1 : (root.rangeProfile || root.verificationRequired) ? rangeCombo.currentIndex + 1 : gpsCombo.currentIndex + 1
        var injection = injectionCombo.currentIndex === 1 ? 127 : instance - 1
        var rows = PeripheralProfiles.build(profile, firmware, portCombo.currentText, instance,
                                        Number(baudCombo.currentText), injection,
                                        controller.parameterExists(-1, "SEP_PORT" + instance + "_CFG"),
                                        {board: powerBoardCombo.currentIndex,
                                         flowFusion: flowFusion.checked,
                                         legacyFlow: vehicle.firmwareMajorVersion > 0 && (vehicle.firmwareMajorVersion < 4 || (vehicle.firmwareMajorVersion === 4 && vehicle.firmwareMinorVersion < 5)),
                                         modernFlow: controller.parameterExists(-1, "EKF2_OF_CTRL"),
                                         flowMavlink1: flowProtocol.checked,
                                         modernMavOptions: root.modernMavOptions,
                                         mavInstance: mavChannel.currentIndex - 1,
                                         canDriver: Number((findFact(["CAN_P" + (portCombo.currentText === "CAN2" ? 2 : 1) + "_DRIVER"]) || {rawValue: 0}).rawValue)})
        if (firmware === "px4" && profile.kind === "sbf" && controller.parameterExists(-1, "SEP_PORT" + instance + "_CFG")) {
            // A GPS module must not open the same UART as the new Septentrio driver.
            for (var i = 1; i <= 2; ++i) {
                var name = "GPS_" + i + "_CONFIG"
                var fact = findFact([name])
                if (fact && Number(fact.rawValue) === PeripheralProfiles.px4Ports[portCombo.currentText]) {
                    rows.unshift({ names: [name], value: 0, note: qsTr("释放同一个 UART，避免旧 GPS 驱动与 Septentrio 驱动争用接口"), optional: false })
                }
            }
        }
        if (!root.verificationRequired) {
            var prefixes = []
            if (root.rangeProfile) prefixes = [firmware === "ap" ? "RNGFND" + instance + "_POS_" : "EKF2_RNG_POS_"]
            else if (profile.kind === "flow") prefixes = [firmware === "ap" ? "FLOW_POS_" : "EKF2_OF_POS_"]
            else if (PeripheralProfiles.category(profile) === "gps") prefixes = [firmware === "ap" ? "GPS" + instance + "_POS_" : "EKF2_GPS_POS_"]
            for (var prefix of prefixes) for (var axis of ["X", "Y", "Z"]) {
                var names = [prefix + axis]
                if (firmware === "ap" && PeripheralProfiles.category(profile) === "gps") names = PeripheralProfiles.gpsNames(instance, "POS_" + axis)
                rows.push({names: names, manual: true, optional: true, note: qsTr("该参数需自行测量后写入；本页不自动修改安装偏移。")})
            }
        }
        return rows
                .map(function(row) { return suggestion(row) })
    }

    function applySuggestions() {
        // Re-check the live vehicle and every required Fact before any write, not only button state.
        ++root.selectionRevision
        if (!root.canApply) return
        for (var i = 0; i < suggestions.length; ++i) {
            var item = suggestions[i]
            if (!root.connected || vehicle.armed || vehicle.flying) return
            if (!item.noWrite && item.fact && !item.fact.readOnly && item.valid && Number(item.fact.rawValue) !== item.value) {
                item.fact.rawValue = item.value
            }
        }
    }

    onAccepted: applySuggestions()

    QGCPalette {
        id: qgcPal
        colorGroupEnabled: true
    }

    ColumnLayout {
        width: Math.min(root.maxContentAvailableWidth, ScreenTools.defaultFontPixelWidth * 105)
        spacing: ScreenTools.defaultDialogControlSpacing

        QGCLabel {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.vehicle && root.vehicle.apmFirmware
                    ? qsTr("当前飞控：ArduPilot。选择设备和实际接线端口后，下方只列出当前飞控真实存在的参数。")
                    : (root.vehicle && root.vehicle.px4Firmware
                       ? qsTr("当前飞控：PX4。建议值会按 PX4 参数体系生成，不会套用 ArduPilot 参数。")
                       : qsTr("当前固件暂不支持自动生成外设配置建议。"))
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2

            QGCLabel { text: qsTr("外设类别") }
            QGCComboBox {
                id: categoryCombo
                objectName: "peripheralCategory"
                Layout.fillWidth: true
                model: PeripheralProfiles.categories.map(category => category.name)
                onActivated: { deviceCombo.currentIndex = 0; root.updateDeviceSelection() }
            }
            QGCLabel { text: qsTr("外设型号（Device）") }
            QGCComboBox {
                id: deviceCombo
                objectName: "peripheralDevice"
                onCurrentIndexChanged: if (root._componentReady) { powerConfirmed.checked = false; flowMountConfirmed.checked = false }
                Layout.fillWidth: true
                model: root.shownProfiles.map(function(profile) { return profile.name })
                onActivated: root.updateDeviceSelection()
            }

            QGCLabel { visible: !root.guideOnly && !root.i2cProfile; text: root.canProfile ? qsTr("连接接口（CAN）") : root.powerProfile ? qsTr("电源连接") : qsTr("连接接口（Serial Port）") }
            QGCComboBox {
                id: portCombo
                objectName: "peripheralSerialPort"
                visible: !root.guideOnly && !root.i2cProfile
                Layout.fillWidth: true
                model: root.portOptions()
                onActivated: { flowMountConfirmed.checked = false; firmwareConfirmed.checked = false; ++root.selectionRevision }
            }

            QGCLabel { text: qsTr("电池监测实例"); visible: root.powerProfile }
            QGCComboBox {
                id: batteryCombo
                objectName: "peripheralBatteryInstance"
                onCurrentIndexChanged: if (root._componentReady) powerConfirmed.checked = false
                Layout.fillWidth: true
                visible: root.powerProfile
                model: [qsTr("电池 1 / POWER1"), qsTr("电池 2 / POWER2")]
                onActivated: { powerConfirmed.checked = false; ++root.selectionRevision }
            }
            QGCLabel { text: qsTr("测距实例"); visible: (root.rangeProfile || root.installationRange) && !!root.vehicle && root.vehicle.apmFirmware }
            QGCComboBox {
                id: rangeCombo
                objectName: "peripheralRangeInstance"
                Layout.fillWidth: true
                visible: (root.rangeProfile || root.installationRange) && !!root.vehicle && root.vehicle.apmFirmware
                model: [qsTr("测距 1"), qsTr("测距 2"), qsTr("测距 3"), qsTr("测距 4")]
                onActivated: { firmwareConfirmed.checked = false; ++root.selectionRevision }
            }
            QGCLabel { text: qsTr("实际飞控型号（ADC 引脚）"); visible: root.selectedProfile().kind === "power-analog" && root.vehicle && root.vehicle.apmFirmware }
            QGCComboBox {
                id: powerBoardCombo
                onCurrentIndexChanged: if (root._componentReady) powerConfirmed.checked = false
                Layout.fillWidth: true
                visible: root.selectedProfile().kind === "power-analog" && root.vehicle && root.vehicle.apmFirmware
                model: PeripheralProfiles.powerBoards
                onActivated: { powerConfirmed.checked = false; ++root.selectionRevision }
            }
            QGCLabel { visible: !root.guideOnly && !root.powerProfile && !root.rangeProfile && !root.elrsProfile && root.selectedProfile().kind !== "telemetry" && root.selectedProfile().kind !== "flow" && !root.verificationRequired; text: qsTr("设为 GPS 编号") }
            QGCComboBox {
                id: gpsCombo
                visible: !root.guideOnly && !root.powerProfile && !root.rangeProfile && !root.elrsProfile && root.selectedProfile().kind !== "telemetry" && root.selectedProfile().kind !== "flow" && !root.verificationRequired
                Layout.fillWidth: true
                model: ["GPS1", "GPS2"]
                onActivated: ++root.selectionRevision
            }
            QGCLabel { visible: !root.guideOnly && !root.canProfile && !root.powerProfile && !root.i2cProfile && root.selectedProfile().kind !== "flow-uart"; text: qsTr("外设波特率") }
            QGCComboBox {
                id: baudCombo
                visible: !root.guideOnly && !root.canProfile && !root.powerProfile && !root.i2cProfile && root.selectedProfile().kind !== "flow-uart"
                enabled: !root.elrsProfile && root.selectedProfile().kind !== "flow" && !(root.vehicle && root.vehicle.px4Firmware && root.rangeProfile)
                Layout.fillWidth: true
                model: ["57600", "115200", "230400", "460800", "420000", "921600"]
                currentIndex: 1
                onActivated: ++root.selectionRevision
            }
            QGCLabel { text: qsTr("实际 MAVLink 通道"); visible: root.needsMavChannel }
            QGCComboBox {
                id: mavChannel
                objectName: "peripheralMavChannel"
                visible: root.needsMavChannel
                Layout.fillWidth: true
                model: [qsTr("请选择实际通道（不等于 SERIAL 号）"), "MAV0", "MAV1", "MAV2", "MAV3", "MAV4", "MAV5"]
                onActivated: { firmwareConfirmed.checked = false; ++root.selectionRevision }
            }
            QGCLabel { visible: !!root.selectedProfile().rtcm && !!root.vehicle && root.vehicle.apmFirmware; text: qsTr("RTCM 注入目标") }
            QGCComboBox {
                id: injectionCombo
                visible: !!root.selectedProfile().rtcm && !!root.vehicle && root.vehicle.apmFirmware
                Layout.fillWidth: true
                model: [qsTr("所选 GPS 编号"), qsTr("GPS1 和 GPS2")]
                onActivated: ++root.selectionRevision
            }
        }

        Rectangle {
            visible: root.guidance.preparation.length > 0
            Layout.fillWidth: true
            implicitHeight: guideColumn.implicitHeight + ScreenTools.defaultFontPixelHeight
            color: "#142737"; radius: 8; border.color: "#36566A"
            ColumnLayout {
                id: guideColumn
                width: parent.width - ScreenTools.defaultFontPixelWidth * 2
                x: ScreenTools.defaultFontPixelWidth; y: ScreenTools.defaultFontPixelHeight / 2
                spacing: ScreenTools.defaultFontPixelHeight * 0.5
                QGCLabel { Layout.fillWidth: true; text: qsTr("配置前准备"); color: "#D6E7F0"; font.bold: true }
                Repeater {
                    model: root.guidance.preparation
                    QGCLabel { required property string modelData; Layout.fillWidth: true; text: "• " + modelData; wrapMode: Text.WordWrap; color: "#B6CBD7" }
                }
                QGCLabel { visible: root.guidance.parameters.length > 0; Layout.fillWidth: true; text: qsTr("参数审核指引 · 按实际安装与当前固件选择"); color: "#E8B56B"; font.bold: true; wrapMode: Text.WordWrap }
                Repeater {
                    model: root.guidance.parameters
                    ColumnLayout {
                        id: guideParameter
                        required property var modelData
                        Layout.fillWidth: true
                        QGCLabel { Layout.fillWidth: true; text: guideParameter.modelData.names[0] + " · " + qsTr("当前：") + root.factDisplay(root.findFact(guideParameter.modelData.names)); color: "#71BBD3"; font.family: ScreenTools.normalFontFamily; wrapMode: Text.WordWrap }
                        QGCLabel { Layout.fillWidth: true; text: guideParameter.modelData.recommendation + "\n" + guideParameter.modelData.note; color: "#B6CBD7"; wrapMode: Text.WordWrap }
                    }
                }
                QGCLabel { text: qsTr("配置后验证"); color: "#D6E7F0"; font.bold: true }
                Repeater {
                    model: root.guidance.verification
                    QGCLabel { required property string modelData; Layout.fillWidth: true; text: "• " + modelData; wrapMode: Text.WordWrap; color: "#B6CBD7" }
                }
                QGCLabel { visible: root.guideOnly; Layout.fillWidth: true; text: qsTr("此项提供厂商配置指南与当前参数对照。导航融合、安装偏移和伴随计算机标定需按实际设备单独审核，不能一键套用；本页不会写入这些指南项。"); wrapMode: Text.WordWrap; color: "#E8B56B" }
            }
        }

        QGCCheckBox {
            id: firmwareConfirmed
            objectName: "peripheralFirmwareConfirmed"
            visible: root.verificationRequired
            Layout.fillWidth: true
            text: qsTr("已核对厂商方案与当前固件、接线及安装一致；确认按下表配置（含列出的融合／高度来源）")
            onCheckedChanged: ++root.selectionRevision
        }
        QGCCheckBox {
            id: flowMountConfirmed
            visible: root.selectedProfile().kind === "flow"
            text: qsTr("已确认光流 / 测距模块向下安装，方向、接线和量程符合实际设备")
        }
        QGCCheckBox {
            id: powerConfirmed
            objectName: "peripheralPowerConfirmed"
            visible: root.powerProfile
            Layout.fillWidth: true
            text: qsTr("已核对电源模块型号、飞控接口和电池实例；应用后自行重启并实测校准")
        }
        QGCCheckBox {
            id: flowFusion
            objectName: "peripheralFlowFusion"
            visible: root.selectedProfile().kind === "flow" && !!root.vehicle && root.vehicle.px4Firmware
            text: qsTr("同时配置光流融合及测距高度参考（已核对安装与使用环境）")
            onCheckedChanged: ++root.selectionRevision
        }
        QGCCheckBox {
            id: flowProtocol
            objectName: "peripheralFlowProtocol"
            visible: flowFusion.visible
            text: qsTr("配置厂商 PX4 1.17+ MAVLink1 兼容项（旧版不需要；可能影响其他链路）")
            onCheckedChanged: ++root.selectionRevision
        }
        QGCLabel {
            visible: root.powerProfile
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: qgcPal.warningText
            text: qsTr("只配置电压/电流监测，不关闭电池、解锁或低电量保护。模拟模块先选实际飞控；Pixhawk 5X/6X 的 I²C POWER 接口不能当模拟 ADC 使用。数字模块节点参数不在此处改写。未连接模块时无法验证读数；缺少必要参数的方案禁止应用。")
        }
        QGCLabel {
            visible: root.selectedProfile().kind === "flow"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("默认只配置传感器接收；导航融合与协议兼容项需单独勾选，并在下方预览实际参数。缺少必需参数时禁止应用，不会假装成功。PX4 要求 MAVLink 实例 1 空闲；应用后重启并验证传感器与估计器状态。")
        }

        QGCLabel {
            visible: !root.guideOnly
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.verificationRequired ? qsTr("以下数字为当前型号的可写方案；确认固件后应用。红色安装／延迟等实测项仅提示，不参与写入。") : qsTr("请按接线文档核对接口及波特率。GNSS 定位方案不自动启用双天线航向。红色安装偏移需实测后单独写入。")
        }
        QGCButton { text: qsTr("查看官方配置资料"); onClicked: Qt.openUrlExternally(PeripheralProfiles.sourceFor(root.selectedProfile(), root.vehicle && root.vehicle.px4Firmware ? "px4" : "ap")) }

        Rectangle {
            visible: !root.guideOnly
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(parameterColumn.implicitHeight + ScreenTools.defaultFontPixelHeight,
                                             root.maxContentAvailableHeight * 0.38)
            color: qgcPal.windowShade
            border.color: qgcPal.groupBorder
            radius: ScreenTools.defaultFontPixelWidth / 2

            QGCFlickable {
                id: parameterFlickable
                objectName: "peripheralParameterScroll"
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth
                contentWidth: width
                contentHeight: parameterColumn.implicitHeight
                clip: true

                ColumnLayout {
                    id: parameterColumn
                    width: parent.width
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 20; text: qsTr("参数") ; font.bold: true }
                        QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 22; text: qsTr("当前值") ; font.bold: true }
                        QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12; text: qsTr("建议值") ; font.bold: true }
                        QGCLabel { Layout.fillWidth: true; text: qsTr("作用") ; font.bold: true }
                    }

                    Repeater {
                        model: root.suggestions

                        Rectangle {
                            id: parameterRow
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: rowLayout.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.5
                            color: modelData.manual || !modelData.fact || !modelData.valid ? Qt.rgba(0.5, 0.15, 0.15, 0.2) : "transparent"

                            RowLayout {
                                id: rowLayout
                                anchors.fill: parent
                                anchors.margins: ScreenTools.defaultFontPixelWidth / 3

                                ColumnLayout {
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 20
                                    QGCLabel { Layout.fillWidth: true; text: parameterRow.modelData.name; color: parameterRow.modelData.manual ? "#FF5252" : qgcPal.text; wrapMode: Text.Wrap }
                                    QGCLabel { Layout.fillWidth: true; visible: parameterRow.modelData.manual; text: parameterRow.modelData.note; color: "#FF5252"; wrapMode: Text.Wrap; font.pointSize: ScreenTools.smallFontPointSize }
                                }
                                QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 22; text: parameterRow.modelData.current; color: parameterRow.modelData.fact ? qgcPal.text : qgcPal.warningText }
                                QGCLabel { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12; text: parameterRow.modelData.recommended; color: parameterRow.modelData.manual ? "#FF5252" : parameterRow.modelData.valid ? qgcPal.colorGreen : qgcPal.warningText }
                                QGCLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: parameterRow.modelData.manual ? qsTr("仅提示，不写入") : parameterRow.modelData.note }
                            }
                        }
                    }
                }
            }
        }

        QGCLabel {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: qgcPal.warningText
            text: root.guideOnly ? qsTr("按上方步骤准备、检查数据及估计器融合；可点击“查看官方配置资料”对照具体硬件版本。")
                    : root.vehicle && root.vehicle.armed
                    ? qsTr("飞行器已解锁，禁止写入外设参数。")
                    : !root.connected ? qsTr("飞控已断连，禁止写入。")
                    : !root.firmwareSupported ? qsTr("此数字电源方案需要 ArduPilot 4.4+；当前固件请按官方资料手动配置。")
                    : root.portConflict ? qsTr("此接口正在用于其他协议或通信，禁止直接覆盖；请选择空闲或兼容接口。")
                    : root.needsMavChannel && mavChannel.currentIndex === 0 ? qsTr("请选择模块对应的实际 MAVLink 通道；MAVLink 通道号不等于 SERIAL 串口号，不能自动猜测。")
                    : root.verificationRequired && !firmwareConfirmed.checked ? qsTr("请核对厂商方案与当前固件、安装及接线，勾选确认后可应用下表数值；红色实测项始终不写入。")
                    : root.blockedCount > 0 ? qsTr("必要参数缺失、只读或不兼容，禁止应用此方案，请核对固件支持。")
                    : root.suggestions.length === 0 ? qsTr("此型号在当前固件暂无已核实方案，请按官方资料手动配置。")
                    : qsTr("点击“应用”只写入预览中的可写参数，不会校准或重启设备。完成后请自行重启飞控，并检查方向、距离量程、GPS 状态和 CAN 终端电阻。")
        }
    }
}
