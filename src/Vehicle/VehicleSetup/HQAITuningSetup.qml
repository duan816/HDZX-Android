pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    property bool isAIWorkspace: true
    property bool logAnalysisOnly: false
    property bool flightCaptureOnly: false
    property var controller: flightCaptureOnly ? captureController : logAnalysisOnly ? diagnosisController : liveController
    property var workspaceInputs: ({})
    property bool diagnosticExpanded: false
    property bool scoreExpanded: false
    property int analysisElapsed: 0
    property string parsedLogPath: ""
    property string appliedRange: ""
    property bool rangeDirty: false
    property var parameters: []
    property var selectedNames: []
    property var selectedProposals: []
    property bool inputsExpanded: false
    property bool hardwareExpanded: false
    property bool viewReady: false
    property bool resettingContext: false
    property string logName: ""
    property string logPath: ""
    property bool restoringRecord: false
    property bool historyExpanded: false
    property double selectionRevision: -1
    property int observedProposalCount: 0
    property var confirmedPlan: []
    property var confirmedVehicle: null
    property var confirmedController: null
    property double confirmedRevision: 0
    readonly property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool contextLocked: controller.busy || controller.writing || controller.batchActive
    readonly property var displayParser: flightCaptureOnly ? HQAIFlightRecorder : logParser
    readonly property var evidence: displayParser.aiEvidence || ({})
    readonly property var identity: evidence.identity || ({})
    readonly property var rateMetrics: evidence.rate_tracking || []
    readonly property var hardwareReport: evidence.hardware_report || ({})
    readonly property int pendingSelectionCount: controller.proposals.filter(function(item) {
        return selectedProposals.indexOf(item.name) >= 0 && !item.applied && (controller.logOnly || item.blocked === "")
    }).length
    readonly property bool hasScore: !displayParser.assessing && (flightCaptureOnly || !rangeDirty) && evidence.tracking_score !== null && evidence.tracking_score !== undefined && isFinite(Number(evidence.tracking_score))
    readonly property bool wide: width >= 1000

    Timer { interval: 1000; repeat: true; running: root.controller.busy; onTriggered: root.analysisElapsed++ }
    Connections {
        target: root.controller
        function onBusyChanged() { if (root.controller.busy) root.analysisElapsed = 0 }
    }
    signal workspaceRequested(bool logsOnly)
    signal configurationRequested()
    HQAITheme { id: theme }
    HQAITuningController { id: liveController }
    HQAITuningController { id: diagnosisController }
    HQAITuningController { id: captureController }
    Rectangle { anchors.fill: parent; color: theme.background; z: -1 }
    LogFileParser { id: logParser; objectName: "aiLocalParser"; onParseCompleteChanged: if (parseComplete) root.applyAnalysisWindow(false) }

    function refreshParameters(invalidate) {
        if (viewReady && invalidate !== false) controller.invalidatePlan()
        parameters = controller.availableParameters()
        selectedNames = parameters.slice(0, 20).map(function(item) { return item.name })
    }
    function workspaceKey() { return flightCaptureOnly ? "capture" : logAnalysisOnly ? "diagnosis" : "tuning" }
    function switchWorkspace(logsOnly) { changeWorkspace(logsOnly, false) }
    function switchCapture() { changeWorkspace(false, true) }
    function changeWorkspace(logsOnly, capture) {
        if (controller.writing || controller.batchActive || (logAnalysisOnly === logsOnly && flightCaptureOnly === capture)) return
        workspaceSave.stop()
        const previous = workspaceData()
        previous.scroll_y = scroll.contentItem.contentY
        previous.selected_proposals = selectedProposals.slice()
        previous.diagnostic_expanded = diagnosticExpanded
        previous.score_expanded = scoreExpanded
        workspaceInputs[workspaceKey()] = previous
        saveWorkspace()
        controller.suspendWritePlan()
        restoringRecord = true
        flightCaptureOnly = capture
        logAnalysisOnly = logsOnly
        const saved = workspaceInputs[workspaceKey()]
        restoreInputs(saved || Object.assign({}, previous, {intent_index: logsOnly ? 2 : 0, diagnostic_expanded: false, score_expanded: false}))
        restoringRecord = false
        refreshParameters(false)
        selectionRevision = controller.planRevision
        observedProposalCount = controller.proposals.length
        selectedProposals = saved ? saved.selected_proposals : []
        if (!capture && logPath !== parsedLogPath) {
            parsedLogPath = logPath
            appliedRange = ""
            if (logPath) logParser.startParsingAsync(logPath); else logParser.clear()
        } else if (!capture && logParser.parseComplete) applyAnalysisWindow(false)
        Qt.callLater(function() { scroll.contentItem.contentY = saved ? saved.scroll_y || 0 : 0 })
        workspaceRequested(logsOnly)
    }
    function choose(name, checked) {
        const names = selectedNames.filter(function(item) { return item !== name })
        if (checked) names.push(name)
        selectedNames = names
        controller.invalidatePlan()
    }
    function contextChanged() { if (viewReady && !contextLocked && !resettingContext && !restoringRecord) { controller.invalidatePlan(); workspaceSave.restart() } }
    function hardware() {
        return {frame_mm: Number(frameSize.text), prop_inches: Number(propSize.text),
            esc_protocol: ["unknown", "PWM", "DShot", "CAN", "Other"][escProtocol.currentIndex],
            rpm_source: ["none", "bidirectional_dshot", "independent", "unknown"][rpmSource.currentIndex],
            rpm_verified: rpmVerified.checked, airframe: airframe.currentText, log_matches_vehicle: logBelongs.checked,
            motor_stator_diameter_mm: numericInput(motorDiameter.text), motor_stator_height_mm: numericInput(motorHeight.text),
            motor_kv_rpm_per_v: numericInput(motorKV.text), battery_cells_s: numericInput(batteryS.text),
            battery_cell_voltage_v: numericInput(cellVoltage.text), battery_capacity_mah: numericInput(capacity.text),
            provenance: "用户手动报告；缺失/无效数字为null，不是实测遥测"}
    }
    function numericInput(text) { return text.trim() !== "" && isFinite(Number(text)) && Number(text) > 0 ? Number(text) : null }
    function hardwareSummary(info) {
        function value(key) { return info[key] !== null && isFinite(Number(info[key])) && Number(info[key]) > 0 ? String(Number(info[key])) : "--" }
        return qsTr("轴距 %1 mm · 桨 %2 英寸 · 定子 %3 × %4 mm · KV %5 rpm/V\n电池 %6 S · 单片 %7 V · 容量 %8 mAh · 电调 %9 · RPM %10")
            .arg(value("frame_mm")).arg(value("prop_inches")).arg(value("motor_stator_diameter_mm")).arg(value("motor_stator_height_mm"))
            .arg(value("motor_kv_rpm_per_v")).arg(value("battery_cells_s")).arg(value("battery_cell_voltage_v")).arg(value("battery_capacity_mah"))
            .arg(info.esc_protocol === "unknown" ? qsTr("未确认") : info.esc_protocol || qsTr("未知"))
            .arg(info.rpm_source === "none" ? qsTr("无回传") : info.rpm_source || qsTr("未知"))
    }
    function analyzeLog() {
        const context = Object.assign({}, evidence)
        context.user_reported_hardware = hardware()
        context.user_reported_hardware.frame_input = frameSize.text
        context.user_reported_hardware.frame_valid = isFinite(Number(frameSize.text)) && Number(frameSize.text) > 0
        saveWorkspace()
        controller.analyzeLog(apiKey.text, model.currentText, analysisProblem(), context, !logAnalysisOnly)
    }
    function analysisProblem() { return qsTr("分析重点：") + intent.currentText + "\n" + qsTr("用户问题：") + (problem.text.trim() || qsTr("未填写具体描述，请先按所选重点检查现有证据。")) }
    function workspaceData() {
        return {log_path: logPath, log_name: logName, workspace: workspaceKey(),
            intent_index: intent.currentIndex, airframe_index: airframe.currentIndex, problem: problem.text,
            frame_text: frameSize.text, prop_text: propSize.text, esc_index: escProtocol.currentIndex, rpm_index: rpmSource.currentIndex,
            rpm_verified: rpmVerified.checked, motor_diameter: motorDiameter.text, motor_height: motorHeight.text, motor_kv: motorKV.text,
            battery_s: batteryS.text, cell_voltage: cellVoltage.text, capacity: capacity.text,
            analysis_begin: analysisBegin.text, analysis_end: analysisEnd.text, manual_exclusions: manualExclusions.text}
    }
    function saveWorkspace(newRecord) {
        if (restoringRecord || logName === "" || flightCaptureOnly) return
        controller.saveWorkspace(workspaceData(), newRecord === true)
    }
    function restoreInputs(saved) {
        logName = saved.log_name || ""; logPath = saved.log_path || ""
        intent.currentIndex = Number(saved.intent_index || 0); airframe.currentIndex = Number(saved.airframe_index || 0)
        problem.text = saved.problem || ""; frameSize.text = saved.frame_text || ""; propSize.text = saved.prop_text || ""
        escProtocol.currentIndex = Number(saved.esc_index || 0); rpmSource.currentIndex = Number(saved.rpm_index || 0); rpmVerified.checked = !!saved.rpm_verified
        motorDiameter.text = saved.motor_diameter || ""; motorHeight.text = saved.motor_height || ""; motorKV.text = saved.motor_kv || ""
        batteryS.text = saved.battery_s || ""; cellVoltage.text = saved.cell_voltage || ""; capacity.text = saved.capacity || ""
        analysisBegin.text = saved.analysis_begin || ""; analysisEnd.text = saved.analysis_end || ""; manualExclusions.text = saved.manual_exclusions || ""
        diagnosticExpanded = !!saved.diagnostic_expanded; scoreExpanded = !!saved.score_expanded
        logBelongs.checked = false
    }
    function restoreRecord(id) {
        let selected = id || ""
        if (!selected) {
            const record = controller.localRecords.find(function(item) { return item.workspace === (root.logAnalysisOnly ? "diagnosis" : "tuning") })
            if (!record) return
            selected = record.id
        }
        const record = controller.localRecords.find(function(item) { return item.id === selected })
        if (record) changeWorkspace(record.workspace === "diagnosis", false)
        const saved = controller.restoreWorkspace(selected)
        if (!saved.log_name) return
        restoringRecord = true
        if (id) { flightCaptureOnly = false; logAnalysisOnly = saved.workspace === "diagnosis" }
        restoreInputs(saved)
        restoringRecord = false
        parsedLogPath = logPath; appliedRange = ""
        if (logPath) logParser.startParsingAsync(logPath)
    }
    function applyAnalysisWindow(invalidate) {
        const begin = analysisBegin.text === "" ? logParser.minTimestamp : Number(analysisBegin.text)
        const end = analysisEnd.text === "" ? logParser.maxTimestamp : Number(analysisEnd.text)
        const exclusions = []
        const parts = manualExclusions.text.split(";")
        for (const part of parts) {
            if (part.trim() === "") continue
            const values = part.trim().split(/\s*[-~]\s*/)
            if (values.length !== 2 || !isFinite(Number(values[0])) || !isFinite(Number(values[1])) || Number(values[1]) <= Number(values[0])) { windowError.text = qsTr("排除区间格式：60-65;120-123，单位秒。"); return }
            exclusions.push({begin: Number(values[0]), end: Number(values[1])})
        }
        if (!isFinite(begin) || !isFinite(end) || end <= begin) { windowError.text = qsTr("请选择有效时间范围。"); return }
        windowError.text = ""
        const signature = JSON.stringify([logPath, begin, end, exclusions])
        rangeDirty = false
        if (appliedRange === signature) return
        if (invalidate !== false) controller.invalidatePlan()
        appliedRange = signature
        logParser.setAIAnalysisWindow(begin, end, exclusions)
        saveWorkspace()
    }
    function selectProposal(name, checked) {
        const names = selectedProposals.filter(function(item) { return item !== name })
        if (checked) names.push(name)
        selectedProposals = names
    }
    function confirmSelected() {
        if (controller.logOnly) {
            const chosen = selectedProposals.slice()
            if (!controller.stageLogSuggestions(hardware())) { hardwareExpanded = true; return }
            selectedProposals = chosen
        }
        confirmedPlan = controller.proposals.filter(function(item) {
            return selectedProposals.indexOf(item.name) >= 0 && !item.applied && item.blocked === ""
        }).map(function(item) { return {name: item.name, before: item.before, value: item.value, unit: item.unit} })
        confirmedVehicle = activeVehicle
        confirmedController = controller
        confirmedRevision = controller.planRevision
        if (confirmedPlan.length > 0) confirmFactory.open()
    }
    function persistKey() {
        if (viewReady && remember.checked && apiKey.text.trim() !== "") controller.rememberApiKey(apiKey.text)
    }
    function displayNumber(value, digits) { return value === null || value === undefined || !isFinite(Number(value)) ? "--" : Number(value).toFixed(digits) }
    function displayParameter(value) { return isFinite(Number(value)) ? String(Number(Number(value).toPrecision(6))) : "--" }
    function batteryText() {
        if (activeVehicle && activeVehicle.batteries && activeVehicle.batteries.count > 0) {
            const battery = activeVehicle.batteries.get(0)
            if (battery && battery.voltage && Number(battery.voltage.value) > 0) return Number(battery.voltage.value).toFixed(1) + " V"
        }
        const item = (evidence.field_statistics || []).find(function(field) { return field.field === "BAT.Volt" })
        return item ? Number(item.mean).toFixed(1) + qsTr(" V · 日志均值") : "--"
    }
    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged() {
            root.resettingContext = true
            logBelongs.checked = false
            frameSize.clear(); propSize.clear()
            escProtocol.currentIndex = 0; rpmSource.currentIndex = 0; rpmVerified.checked = false
            root.resettingContext = false
            root.refreshParameters(false)
        }
    }
    Connections {
        target: root.controller
        function onStateChanged() {
            const count = root.controller.proposals.length
            if (root.selectionRevision !== root.controller.planRevision || (root.observedProposalCount === 0 && count > 0)) {
                root.selectionRevision = root.controller.planRevision
                root.selectedProposals = root.controller.proposals.filter(function(item) { return !item.applied && (root.controller.logOnly || item.blocked === "") }).map(function(item) { return item.name })
            }
            root.observedProposalCount = count
        }
    }
    Component.onCompleted: {
        apiKey.text = controller.rememberedApiKey()
        refreshParameters(false)
        restoreRecord("")
        viewReady = true
    }
    function cancelControllers() { for (const item of [liveController, diagnosisController, captureController]) { if (item.busy || item.writing || item.batchActive) item.cancel(); item.suspendWritePlan() } }
    onVisibleChanged: if (viewReady && !visible) { saveWorkspace(); persistKey(); cancelControllers() }
    Component.onDestruction: { workspaceSave.stop(); saveWorkspace(); persistKey(); liveController.cancel(); diagnosisController.cancel(); captureController.cancel() }
    Timer { id: keySave; interval: 500; onTriggered: root.persistKey() }
    Timer { id: workspaceSave; interval: 700; onTriggered: root.saveWorkspace() }
    QGCFileDialog {
        id: fileDialog
        title: qsTr("选择 AP / PX4 飞行日志")
        nameFilters: [qsTr("飞控日志 (*.bin *.BIN *.log *.LOG *.ulg *.ULG)")]
        onAcceptedForLoad: function(file) {
            root.controller.invalidatePlan()
            root.logName = String(file).split(/[\\/]/).pop()
            root.logPath = String(file)
            root.parsedLogPath = root.logPath; root.appliedRange = ""
            root.restoringRecord = true
            analysisBegin.clear(); analysisEnd.clear(); manualExclusions.clear()
            root.restoringRecord = false
            logBelongs.checked = false
            logParser.startParsingAsync(file)
            root.saveWorkspace(true)
        }
    }
    Connections { target: logParser; function onAssessmentChanged() { if (!logParser.assessing && logParser.parseComplete) root.saveWorkspace() } }
    QGCPopupDialogFactory { id: confirmFactory; dialogComponent: confirmation }
    Component {
        id: confirmation
        QGCPopupDialog {
            title: root.confirmedPlan.some(function(item) { return item.name === "LOG_BITMASK" || item.name === "SDLOG_PROFILE" }) ? qsTr("确认快速采样设置") : qsTr("确认写入所选参数")
            buttons: Dialog.Cancel | Dialog.Apply
            ColumnLayout {
                spacing: 10
                QGCLabel { text: root.confirmedVehicle ? qsTr("目标：%1 号机 · %2 项差异").arg(root.confirmedVehicle.id).arg(root.confirmedPlan.length) : qsTr("目标已断开") }
                Repeater { model: root.confirmedPlan; QGCLabel { required property var modelData; font.family: theme.monoFamily; text: modelData.name + "   " + modelData.before + " → " + modelData.value + " " + modelData.unit } }
                QGCLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: qsTr("风险：AI 建议或快照可能不适合当前飞机。PID、滤波修改可能引起振荡、控制滞后、失稳或坠机；范围校验不代表安全。请先核对机型、桨、电调、RPM 来源与真实曲线。") }
                QGCLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: qsTr("未解锁地面状态才允许提交。先保存原值，再逐项等待飞控匹配回执；异常会停止剩余项。可能部分完成，取消不能撤回已发出的修改。不自动重启、解锁、电机测试或回滚。") }
                QGCLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: qsTr("采样设置会增加 CPU / 存储负载，部分固件下次启动才生效。不修改物理传感器采样率，不开启原始 IMU/FIFO，不补造旧日志数据。请先检查存储空间。") }
            }
            onAccepted: if (root.confirmedVehicle === root.activeVehicle && root.confirmedController === root.controller) root.controller.applyAll(root.confirmedRevision, root.confirmedPlan.map(function(item) { return item.name }))
        }
    }

    component Mono: Text { font.family: theme.monoFamily; font.pointSize: 10; color: theme.text; textFormat: Text.PlainText }
    component Label: Text { font.family: theme.fontFamily; font.pointSize: 10; color: theme.text; textFormat: Text.PlainText }
    component NavButton: Button {
        id: nav
        property bool selected: false
        implicitHeight: 40
        leftPadding: 14
        contentItem: RowLayout {
            spacing: 10
            Mono { text: "AI"; color: nav.selected ? theme.amber : theme.dim; font.bold: true }
            Label { Layout.fillWidth: true; text: nav.text; color: nav.selected ? theme.amber : theme.dim }
        }
        background: Rectangle {
            color: nav.selected ? theme.panel : "transparent"
            Rectangle { width: 2; height: parent.height; color: theme.amber; visible: nav.selected }
            border.color: nav.activeFocus ? theme.cyan : "transparent"
        }
    }

    Rectangle {
        id: topBar
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: root.width < 600 ? 132 : root.width < 1100 ? 100 : 54
        color: "#0f141c"
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: theme.border }
        GridLayout {
            anchors.fill: parent; anchors.margins: 12
            columns: root.width < 600 ? 2 : root.width < 1100 ? 3 : 5
            columnSpacing: 20
            RowLayout { Layout.columnSpan: root.width < 600 ? 2 : 1; Label { text: "●"; color: theme.amber }
 Label { text: qsTr("AI 调参控制台"); font.bold: true; font.pointSize: 12 }
 Mono { text: "AI"; color: theme.violet } }
            ColumnLayout {
                spacing: 2
                Label { text: logParser.parseComplete ? qsTr("日志机型 / 飞控") : qsTr("飞行器"); color: theme.dim; font.pointSize: 8 }
                Mono { text: root.identity.board || root.identity.vehicle_type || (root.activeVehicle ? qsTr("%1 号机").arg(root.activeVehicle.id) : qsTr("未连接")); elide: Text.ElideRight; Layout.maximumWidth: 180; Layout.fillWidth: true; Layout.minimumWidth: 0 }
            }
            ColumnLayout {
                spacing: 2
                Label { text: logParser.parseComplete ? qsTr("日志固件") : qsTr("固件"); color: theme.dim; font.pointSize: 8 }
                Mono { text: root.identity.firmware || (root.activeVehicle && root.activeVehicle.firmwareMajorVersion >= 0 ? root.activeVehicle.firmwareTypeString + " " + root.activeVehicle.firmwareMajorVersion + "." + root.activeVehicle.firmwareMinorVersion + "." + root.activeVehicle.firmwarePatchVersion : qsTr("未上报")); Layout.maximumWidth: 240; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
            }
            ColumnLayout { spacing: 2; Label { text: root.activeVehicle ? qsTr("当前电池 / 链路") : qsTr("日志数据"); color: theme.dim; font.pointSize: 8 }
 Mono { text: root.batteryText() + (root.activeVehicle && root.activeVehicle.vehicleLinkManager ? " · " + root.activeVehicle.vehicleLinkManager.primaryLinkName : ""); color: theme.cyan; Layout.maximumWidth: 240; elide: Text.ElideRight } }
            RowLayout {
                Layout.fillWidth: true; Layout.alignment: Qt.AlignRight
                Label { text: root.activeVehicle ? root.activeVehicle.flightMode : qsTr("离线分析"); color: theme.cyan }
                Rectangle { implicitWidth: armLabel.implicitWidth + 16; implicitHeight: 24; color: "transparent"; border.color: theme.border; radius: 3
                    Label { id: armLabel; anchors.centerIn: parent; text: root.activeVehicle ? root.activeVehicle.armed ? qsTr("已解锁") : qsTr("未解锁") : "--"; color: root.activeVehicle ? root.activeVehicle.armed ? theme.red : theme.green : theme.dim; font.pointSize: 9 }
                }
            }
        }
    }
    Rectangle {
        id: navigation
        anchors.left: parent.left; anchors.top: topBar.bottom; anchors.bottom: parent.bottom
        width: root.wide ? 212 : 0
        visible: root.wide
        color: "#0e131b"
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: theme.border }
        ColumnLayout {
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
            spacing: 6
            NavButton { Layout.fillWidth: true; text: qsTr("飞行调参"); selected: !root.logAnalysisOnly && !root.flightCaptureOnly; onClicked: root.switchWorkspace(false) }
            NavButton { Layout.fillWidth: true; text: qsTr("日志分析"); selected: root.logAnalysisOnly; onClicked: root.switchWorkspace(true) }
            NavButton { Layout.fillWidth: true; text: qsTr("飞行记录与报告"); selected: root.flightCaptureOnly; onClicked: root.switchCapture() }
            HQAIActionButton { Layout.fillWidth: true; text: qsTr("参数与硬件"); onClicked: root.hardwareExpanded = !root.hardwareExpanded }
            HQAIActionButton { Layout.fillWidth: true; text: qsTr("API 设置"); onClicked: root.inputsExpanded = !root.inputsExpanded }
            HQAIActionButton { Layout.fillWidth: true; text: qsTr("本地记录"); onClicked: root.historyExpanded = !root.historyExpanded }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: theme.border }
            HQAIActionButton { objectName: "aiReturnConfiguration"; Layout.fillWidth: true; implicitHeight: 44; primary: true; font.bold: true; text: qsTr("‹  返回飞机配置"); Accessible.description: qsTr("返回进入 AI 控制台前的配置页面"); onClicked: root.configurationRequested() }
        }
        HQAICard {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10
            heading: root.flightCaptureOnly ? qsTr("当前飞行记录") : qsTr("当前分析来源")
            Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.flightCaptureOnly ? HQAIFlightRecorder.reportPath.split(/[\\/]/).pop() || qsTr("等待飞机解锁采集") : root.logName || qsTr("等待导入日志"); font.pointSize: 9; color: theme.dim }
            Mono { text: root.flightCaptureOnly ? HQAIFlightRecorder.sampleCount + qsTr(" 字段点") : logParser.parseComplete ? logParser.sampleCount.toLocaleString(Qt.locale(), "f", 0) + qsTr(" 条记录") : "--"; color: theme.cyan; font.pointSize: 9 }
            Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.flightCaptureOnly ? qsTr("飞行只记录 · 锁定后分析") : root.logAnalysisOnly ? qsTr("只读日志分析") : root.activeVehicle ? qsTr("写入需人工确认与飞控回执") : qsTr("离线可分析，连接后核对写入"); font.pointSize: 9; color: theme.dim }
        }
    }
    ScrollView {
        id: scroll
        objectName: "aiEvidenceScroll"
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        anchors.left: navigation.right; anchors.right: parent.right; anchors.top: topBar.bottom; anchors.bottom: parent.bottom
        clip: true
        ColumnLayout {
            id: pageBody
            width: scroll.availableWidth - 28
            x: 14
            spacing: 14
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 14
                Label { Layout.fillWidth: true; text: root.flightCaptureOnly ? qsTr("飞行记录与报告") : root.logAnalysisOnly ? qsTr("日志分析") : qsTr("飞行调参"); font.pointSize: 15; font.bold: true }
                HQAIActionButton { visible: !root.wide; text: qsTr("调参"); selected: !root.logAnalysisOnly; onClicked: root.switchWorkspace(false) }
                HQAIActionButton { visible: !root.wide; text: qsTr("日志"); selected: root.logAnalysisOnly; onClicked: root.switchWorkspace(true) }
                HQAIActionButton { visible: !root.wide; primary: true; text: qsTr("‹ 返回配置"); onClicked: root.configurationRequested() }
            }
            Flow {
                Layout.fillWidth: true; spacing: 8
                HQAIActionButton { visible: !root.flightCaptureOnly; text: qsTr("导入日志"); enabled: !root.contextLocked; onClicked: fileDialog.openForLoad() }
                HQAIActionButton { objectName: "aiAnalyzeLogButton"; visible: !root.flightCaptureOnly; text: qsTr("分析日志"); primary: true; enabled: !root.contextLocked && !logParser.parsing && !logParser.assessing && (root.evidence.field_statistics || []).length > 0; onClicked: root.analyzeLog() }
                HQAIActionButton { objectName: "aiAnalyzeParametersButton"; text: qsTr("分析当前参数"); visible: !root.logAnalysisOnly && !root.flightCaptureOnly; enabled: !root.contextLocked && root.selectedNames.length > 0; onClicked: root.controller.analyze(apiKey.text, model.currentText, root.analysisProblem(), root.selectedNames, root.hardware(), logBelongs.checked ? root.evidence : {}) }
                HQAIActionButton { text: qsTr("API 设置"); visible: !root.wide; onClicked: root.inputsExpanded = !root.inputsExpanded }
                HQAIActionButton { text: qsTr("硬件 / 问题"); visible: !root.wide; onClicked: root.hardwareExpanded = !root.hardwareExpanded }
                HQAIActionButton { text: qsTr("取消分析"); visible: root.controller.busy; onClicked: root.controller.cancel() }
                HQAIActionButton { text: qsTr("停止剩余项"); danger: true; visible: root.controller.batchActive; onClicked: root.controller.cancel() }
                HQAIActionButton { text: qsTr("飞行记录"); visible: !root.wide; onClicked: root.switchCapture() }
                HQAIActionButton { text: qsTr("本地记录"); visible: !root.wide; onClicked: root.historyExpanded = !root.historyExpanded }
                HQAIActionButton { text: qsTr("准备快速采样"); visible: !root.logAnalysisOnly && !root.flightCaptureOnly; enabled: !root.contextLocked && !!root.activeVehicle; onClicked: { if (root.controller.stageFastLogging()) root.confirmSelected() } }
            }
            Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.dim; text: root.flightCaptureOnly ? qsTr("启用跟机采集后，飞行中只保存真实遥测，收到实际锁定后生成报告。") : root.logAnalysisOnly ? qsTr("硬件与故障诊断：CPU、内存、IMU、供电与事件；保留碰撞证据，不生成写入参数。") : qsTr("PID 与滤波调试：有效飞行段、阶跃响应、时频谱与可审核的参数差异。快速采样只配置下一份日志，不补造旧日志数据。") }
            HQAICard {
                visible: root.flightCaptureOnly; Layout.fillWidth: true; heading: qsTr("解锁时采集，锁定后报告")
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.cyan; text: HQAIFlightRecorder.status }
                Mono { text: qsTr("采集字段点数：") + HQAIFlightRecorder.sampleCount + " · " + root.displayNumber(HQAIFlightRecorder.maxTimestamp,1) + " s" }
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.text; text: HQAIFlightRecorder.aiSummary; visible: text !== "" }
                HQAIToggle { id: autoFlightAi; text: qsTr("锁定后自动调用自己的 DeepSeek API"); checked: false; enabled: !HQAIFlightRecorder.recording }
                Flow { Layout.fillWidth: true; spacing: 8
                    HQAIActionButton { text: HQAIFlightRecorder.enabled ? qsTr("关闭跟机采集") : qsTr("启用跟机采集"); enabled: !HQAIFlightRecorder.recording; onClicked: HQAIFlightRecorder.configure(!HQAIFlightRecorder.enabled,autoFlightAi.checked,root.hardware()) }
                    HQAIActionButton { text: qsTr("分析锁定后报告"); enabled: !HQAIFlightRecorder.recording && !HQAIFlightRecorder.assessing && HQAIFlightRecorder.parseComplete && !root.contextLocked; onClicked: root.analyzeLog() }
                }
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.dim; text: qsTr("飞行中不调用模型、不写参数。只接收已上报的遥测，不自动改变消息频率；没有目标角速率时不补造。切机、断链或 300000 字段点上限会生成不完整报告，不能当作完整飞行。自动 AI 使用你已保存在本机的密钥。") }
                HQAICombo { id: captureChoice; Layout.fillWidth: true; model: HQAIFlightRecorder.localCaptures.map(function(item) {return item.name}) }
                Flow { Layout.fillWidth: true; spacing: 8
                    HQAIActionButton { text: qsTr("打开飞行记录"); enabled: !HQAIFlightRecorder.recording && !HQAIFlightRecorder.assessing && captureChoice.currentIndex>=0; onClicked: HQAIFlightRecorder.loadReport(HQAIFlightRecorder.localCaptures[captureChoice.currentIndex].path) }
                    HQAIActionButton { text: qsTr("删除所选飞行报告与遥测"); danger: true; enabled: !HQAIFlightRecorder.recording && !HQAIFlightRecorder.assessing && captureChoice.currentIndex>=0; onClicked: HQAIFlightRecorder.deleteCapture(HQAIFlightRecorder.localCaptures[captureChoice.currentIndex].path) }
                }
            }
            HQAICard {
                visible: root.historyExpanded; Layout.fillWidth: true; heading: qsTr("本地分析记录")
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.dim; text: qsTr("保存日志路径、硬件、结论和历史；不保存 API，不复制大日志。历史只读，旧确认不恢复。删除不会删除原始日志。") }
                HQAICombo { id: localRecordChoice; Layout.fillWidth: true; model: root.controller.localRecords.map(function(item) { return (item.name || qsTr("未命名日志")) + " · " + item.time + " · " + (item.workspace === "diagnosis" ? qsTr("故障诊断") : qsTr("飞行调参")) }) }
                Flow {
                    Layout.fillWidth: true; spacing: 8
                    HQAIActionButton { text: qsTr("打开记录"); enabled: !root.contextLocked && localRecordChoice.currentIndex >= 0; onClicked: root.restoreRecord(root.controller.localRecords[localRecordChoice.currentIndex].id) }
                    HQAIActionButton { text: qsTr("删除所选记录"); danger: true; enabled: !root.contextLocked && localRecordChoice.currentIndex >= 0; onClicked: {
                        const id = root.controller.localRecords[localRecordChoice.currentIndex].id
                        const current = id === root.controller.currentRecordId
                        if (root.controller.deleteLocalRecord(id) && current) { root.logName = ""; root.logPath = ""; logParser.clear(); root.controller.invalidatePlan() }
                    } }
                }
                Label { visible: root.controller.localRecords.length === 0; text: qsTr("暂无本地记录"); color: theme.dim }
            }
            HQAICard {
                visible: root.inputsExpanded; Layout.fillWidth: true; heading: qsTr("DeepSeek 连接设置")
                RowLayout {
                    Layout.fillWidth: true
                    HQAIInput { id: apiKey; objectName: "aiApiKeyInput"; Layout.fillWidth: true; placeholderText: qsTr("填写自己的 DeepSeek API Key"); echoMode: TextInput.Password; enabled: !root.contextLocked; onTextEdited: if (root.viewReady) keySave.restart(); onEditingFinished: root.persistKey() }
                    HQAICombo { id: model; model: ["deepseek-flash", "deepseek-v4-pro"]; Layout.preferredWidth: 190; enabled: !root.contextLocked }
                }
                Flow {
                    Layout.fillWidth: true; spacing: 10
                    HQAIToggle { id: remember; text: qsTr("记住密钥 · 本机安全存储"); checked: root.controller.keyStorageAvailable; enabled: root.controller.keyStorageAvailable; onClicked: if (checked) root.persistKey(); else { keySave.stop(); root.controller.forgetApiKey(); apiKey.clear() } }
                    HQAIActionButton { objectName: "aiClearKey"; text: qsTr("清除密钥"); onClicked: { keySave.stop(); root.controller.forgetApiKey(); apiKey.clear(); remember.checked = false } }
                }
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.controller.credentialStatus || (apiKey.text !== "" ? qsTr("已加载你之前保存在本机的密钥；安装包没有默认 API。") : qsTr("安装包没有默认 API；填写自己的密钥，可选本机安全保存。")); color: theme.dim; font.pointSize: 9 }
            }
            HQAICard {
                visible: root.hardwareExpanded; Layout.fillWidth: true; heading: qsTr("问题与硬件边界")
                RowLayout { Layout.fillWidth: true; HQAICombo { id: intent; objectName: "aiProblemIntent"; Layout.fillWidth: true; model: [qsTr("控制跟踪与飞行调参"), qsTr("振动与滤波排查"), qsTr("炸机 / 失稳原因排查"), qsTr("常规日志体检")]; enabled: !root.contextLocked; onCurrentIndexChanged: root.contextChanged() }
 HQAICombo { id: airframe; Layout.fillWidth: true; model: [qsTr("多旋翼"), qsTr("固定翼"), qsTr("直升机"), qsTr("其他")]; enabled: !root.contextLocked; onCurrentIndexChanged: root.contextChanged() } }
                HQAIInput { id: problem; objectName: "aiProblemDescription"; Layout.fillWidth: true; placeholderText: qsTr("描述问题、载荷、风况与可疑时间段"); enabled: !root.contextLocked; onTextChanged: root.contextChanged() }
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.dim; text: qsTr("下一次分析的问题：\n") + root.analysisProblem() }
                Label { objectName: "aiSubmittedProblem"; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.violet; visible: root.controller.submittedProblem !== ""; text: qsTr("最近实际提交给 DeepSeek：\n") + root.controller.submittedProblem }
                GridLayout {
                    Layout.fillWidth: true; columns: pageBody.width < 700 ? 2 : 4
                    Label { text: qsTr("轴距 / mm"); color: theme.dim }
                    HQAIInput { id: frameSize; objectName: "aiFrameSize"; Layout.fillWidth: true; placeholderText: qsTr("真实轴距"); monospace: true; enabled: !root.contextLocked; onTextChanged: root.contextChanged() }
                    Label { text: qsTr("桨 / 英寸"); color: theme.dim }
                    HQAIInput { id: propSize; Layout.fillWidth: true; placeholderText: qsTr("真实桨尺寸"); monospace: true; enabled: !root.contextLocked; onTextChanged: root.contextChanged() }
                    Label { text: qsTr("电调协议"); color: theme.dim }
                    HQAICombo { id: escProtocol; Layout.fillWidth: true; model: [qsTr("未确认"), "PWM", "DShot", "CAN", qsTr("其他")]; enabled: !root.contextLocked; onCurrentIndexChanged: root.contextChanged() }
                    Label { text: qsTr("RPM 来源"); color: theme.dim }
                    HQAICombo { id: rpmSource; Layout.fillWidth: true; model: [qsTr("无转速回传"), qsTr("双向 DShot"), qsTr("独立 / 串口 / CAN"), qsTr("未确认")]; enabled: !root.contextLocked; onCurrentIndexChanged: root.contextChanged() }
                    Label { text: qsTr("定子直径 / mm"); color: theme.dim }
                    HQAIInput { id: motorDiameter; objectName: "aiMotorDiameter"; Layout.fillWidth: true; placeholderText: qsTr("实填，例如 22"); enabled: !root.contextLocked; onTextChanged: root.contextChanged() }
                    Label { text: qsTr("定子高度 / mm"); color: theme.dim }
                    HQAIInput { id: motorHeight; objectName: "aiMotorHeight"; Layout.fillWidth: true; placeholderText: qsTr("实填，例如 12"); enabled: !root.contextLocked; onTextChanged: root.contextChanged() }
                    Label { text: qsTr("电机 KV / rpm/V"); color: theme.dim }
                    HQAIInput { id: motorKV; objectName: "aiMotorKV"; Layout.fillWidth: true; placeholderText: qsTr("实填"); enabled: !root.contextLocked; onTextChanged: root.contextChanged() }
                    Label { text: qsTr("电池 / S"); color: theme.dim }
                    HQAIInput { id: batteryS; objectName: "aiBatteryS"; Layout.fillWidth: true; placeholderText: qsTr("串联节数"); enabled: !root.contextLocked; onTextChanged: root.contextChanged() }
                    Label { text: qsTr("单片电压 / V"); color: theme.dim }
                    HQAIInput { id: cellVoltage; objectName: "aiCellVoltage"; Layout.fillWidth: true; placeholderText: qsTr("本次参考电压"); enabled: !root.contextLocked; onTextChanged: root.contextChanged() }
                    Label { text: qsTr("容量 / mAh"); color: theme.dim }
                    HQAIInput { id: capacity; objectName: "aiBatteryCapacity"; Layout.fillWidth: true; placeholderText: qsTr("标称容量"); enabled: !root.contextLocked; onTextChanged: root.contextChanged() }
                }
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; visible: frameSize.text !== "" && (!isFinite(Number(frameSize.text)) || Number(frameSize.text) <= 0); color: theme.red; text: qsTr("轴距请填毫米数值，例如 450；F450 是机架名称，不能作为已核实轴距。日志基线分析仍可继续。") }
                HQAIToggle { id: rpmVerified; text: qsTr("已核实真实双向 DShot RPM 数据"); visible: rpmSource.currentIndex === 1; checked: false; enabled: !root.contextLocked; onCheckedChanged: root.contextChanged() }
                HQAIToggle { id: logBelongs; text: qsTr("已核对：日志属于当前飞机与配置"); enabled: !root.contextLocked; onCheckedChanged: root.contextChanged() }
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.dim; font.pointSize: 9; text: qsTr("PWM 与 RPM 来源分别核对；普通 DShot 配置不代表真实回传。大轴距与大桨滤波不能套用小型机；本版不自动启用新 RPM / 陷波模式。") }
                Label { objectName: "aiHardwarePreview"; Layout.fillWidth: true; wrapMode: Text.Wrap; color: theme.cyan; font.pointSize: 9; text: qsTr("下一次分析会发送：\n") + root.hardwareSummary(root.hardware()) }
                Label { Layout.fillWidth: true; wrapMode: Text.Wrap; color: theme.dim; font.pointSize: 8; visible: Object.keys(root.controller.submittedHardware || {}).length > 0; text: qsTr("最近已提交硬件：\n") + root.hardwareSummary(root.controller.submittedHardware) }
                RowLayout { visible: !root.logAnalysisOnly; HQAIActionButton { text: qsTr("读取当前参数"); enabled: !root.contextLocked; onClicked: root.refreshParameters() }
 Label { text: qsTr("选择最多 20 项"); color: theme.dim } }
                Flow { Layout.fillWidth: true; visible: !root.logAnalysisOnly; spacing: 10
                    Repeater { model: root.parameters; QGCCheckBox { required property var modelData; text: modelData.name; textColor: theme.text; checked: root.selectedNames.indexOf(modelData.name) >= 0; enabled: !root.contextLocked; onClicked: root.choose(modelData.name, checked) } }
                }
            }
            ProgressBar { Layout.fillWidth: true; visible: logParser.parsing; value: logParser.parseProgress }
            HQAICard {
                objectName: "aiBusyStatus"; Layout.fillWidth: true; visible: root.controller.busy; accent: theme.violet
                RowLayout {
                    Layout.fillWidth: true
                    BusyIndicator { running: root.controller.busy; Layout.preferredWidth: 30; Layout.preferredHeight: 30 }
                    Label { Layout.fillWidth: true; text: qsTr("AI 正在分析 · 已等待 %1 秒，可使用“取消分析”停止本次请求").arg(root.analysisElapsed); color: theme.violet; wrapMode: Text.WordWrap }
                }
                ProgressBar { Layout.fillWidth: true; indeterminate: true }
            }
            Label {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.dim; font.pointSize: 9
                text: root.flightCaptureOnly ? HQAIFlightRecorder.status : logParser.parseError || (logParser.parsing ? qsTr("正在本地解析 %1").arg(root.logName) : logParser.assessing ? qsTr("正在计算真实跟踪指标与证据摘要…") : logParser.parseComplete ? qsTr("%1 · %2 条记录 · 仅发送统计与计算指标，不上传二进制或位置。").arg(root.logName).arg(logParser.sampleCount) : qsTr("导入 AP .bin/.log 或 PX4 .ulg。两种工作区均支持分析日志；写入需要连接并核对目标。"))
            }
            GridLayout {
                Layout.fillWidth: true; columns: pageBody.width < 650 ? 1 : 3; columnSpacing: 12; rowSpacing: 12
                HQAICard { Layout.fillWidth: true; Layout.minimumHeight: 142; Layout.alignment: Qt.AlignTop; accent: theme.violet
                    Label { text: qsTr("AI 诊断"); color: theme.violet; font.pointSize: 9 }
                    Label { objectName: "aiDiagnosisText"; Layout.fillWidth: true; wrapMode: Text.Wrap; text: root.controller.busy ? qsTr("正在分析真实证据") : root.controller.diagnosis || (root.controller.summary !== "" ? root.controller.analysisOutcome : qsTr("等待分析")); font.pointSize: 14; font.bold: true }
                    Label { Layout.fillWidth: true; wrapMode: Text.Wrap; text: root.controller.status || qsTr("先识别固件与机型，再审查跟踪、振动与参数。"); color: theme.dim; font.pointSize: 9 }
                    HQAIActionButton { objectName: "aiExpandDiagnosis"; Layout.fillWidth: true; visible: root.controller.summary !== "" || root.controller.questions !== ""; text: root.diagnosticExpanded ? qsTr("收起完整诊断") : qsTr("展开完整诊断与建议依据"); onClicked: root.diagnosticExpanded = !root.diagnosticExpanded }
                }
                HQAICard { Layout.fillWidth: true; Layout.minimumHeight: 142; Layout.alignment: Qt.AlignTop; visible: !root.logAnalysisOnly
                    Label { text: qsTr("跟踪参考评分"); color: theme.dim; font.pointSize: 9 }
                    RowLayout { Mono { objectName: "aiTrackingScore"; text: root.hasScore ? Number(root.evidence.tracking_score).toFixed(1) : "--"; font.pointSize: 25; font.bold: true }
 Mono { text: "/ 100"; color: theme.dim } }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3; color: theme.border; Rectangle { height: parent.height; width: root.hasScore ? parent.width * Math.max(0, Math.min(100, Number(root.evidence.tracking_score))) / 100 : 0; color: theme.amber; radius: 3 } }
                    RowLayout { Layout.fillWidth: true; Repeater { model: [0, 25, 50, 75, 100]; Mono { required property int modelData; Layout.fillWidth: true; text: modelData; font.pointSize: 7; color: theme.dim; horizontalAlignment: modelData === 100 ? Text.AlignRight : Text.AlignLeft } } }
                    Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.displayParser.assessing || root.rangeDirty ? qsTr("区间已变化，等待重新计算") : root.hasScore ? qsTr("有效动作的目标 / 实际 RMS 误差 · 非安全评级") : qsTr("没有可评分的有效目标 / 实际动作"); color: theme.dim; font.pointSize: 8 }
                    HQAIActionButton { objectName: "aiExpandScore"; Layout.fillWidth: true; text: root.scoreExpanded ? qsTr("收起评分依据") : qsTr("查看逐轴评分与区间"); onClicked: root.scoreExpanded = !root.scoreExpanded }
                }
                HQAICard { Layout.fillWidth: true; Layout.minimumHeight: 142; Layout.alignment: Qt.AlignTop; visible: !root.logAnalysisOnly
                    Label { text: root.controller.logOnly ? qsTr("待核对改动") : qsTr("待应用改动"); color: theme.dim; font.pointSize: 9 }
                    RowLayout { Mono { text: root.pendingSelectionCount; font.pointSize: 25; font.bold: true }
 Label { text: qsTr("项"); color: theme.dim } }
                    Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.controller.analysisOutcome || qsTr("只列真实差异；原值不会重复列入建议。"); color: theme.dim; font.pointSize: 9 }
                }
            }
            HQAICard {
                objectName: "aiTimeDomainAdvice"; Layout.fillWidth: true
                visible: !root.logAnalysisOnly && root.rateMetrics.length > 0 && !root.displayParser.assessing && (root.flightCaptureOnly || !root.rangeDirty)
                heading: qsTr("时间域调试推荐 · 本地证据参考")
                caption: qsTr("先看目标与实际，不以缺少 RPM / 原始 IMU 频谱为分析门槛。以下是调试方向，证据不足部分明确列出；不自动写入参数。")
                Repeater {
                    model: root.rateMetrics
                    ColumnLayout {
                        id: timeAdvice
                        required property var modelData
                        readonly property var temporal: modelData.temporal_analysis || ({})
                        Layout.fillWidth: true
                        Mono { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.cyan; text: timeAdvice.modelData.axis + " · " + (timeAdvice.modelData.target_field || "--") + " / " + (timeAdvice.modelData.actual_field || "--") }
                        Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; visible: text !== ""; text: timeAdvice.modelData.source_basis || ""; color: theme.dim; font.pointSize: 8 }
                        Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: timeAdvice.temporal.baseline || qsTr("缺少有效目标/实际时间序列，无法判断调参方向。"); color: theme.text }
                        Mono {
                            Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.dim; font.pointSize: 8
                            text: qsTr("区间 %1–%2 s · 幅值比 %3 · RMSE %4 %5 · 滞后 %6 ms · 采样 %7 Hz")
                                .arg(root.displayNumber(timeAdvice.temporal.start_seconds, 2)).arg(root.displayNumber(timeAdvice.temporal.end_seconds, 2))
                                .arg(root.displayNumber(timeAdvice.temporal.std_amplitude_ratio, 2)).arg(root.displayNumber(timeAdvice.temporal.rmse, 2))
                                .arg(timeAdvice.modelData.unit || "").arg(root.displayNumber(timeAdvice.temporal.lag_ms, 1)).arg(root.displayNumber(timeAdvice.temporal.sample_rate_hz, 1))
                        }
                        Label {
                            Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.amber; font.pointSize: 9
                            text: qsTr("证据限制：%1\n%2\n%3")
                                .arg((timeAdvice.temporal.missing_enhancements || []).join("、") || qsTr("仍需核对滤波配置、输出饱和与机体状态"))
                                .arg(timeAdvice.temporal.scope || qsTr("未确认空中状态"))
                                .arg(timeAdvice.temporal.sampling_limit || qsTr("仅依据时间域作基线判断，不据此确定 D 或陷波频率。"))
                        }
                    }
                }
            }
            HQAICard {
                objectName: "aiFullDiagnosis"; visible: root.diagnosticExpanded; Layout.fillWidth: true; heading: qsTr("完整诊断与建议依据")
                TextArea { Layout.fillWidth: true; readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; textFormat: TextEdit.PlainText; background: null; color: theme.text; font.family: theme.fontFamily; font.pointSize: 10; text: root.controller.summary + (root.controller.questions !== "" ? "\n\n" + qsTr("需要补充：\n") + root.controller.questions : "") }
            }
            HQAICard {
                objectName: "aiScoreDetails"; visible: root.scoreExpanded && !root.logAnalysisOnly; Layout.fillWidth: true; heading: qsTr("跟踪评分依据 · 本地真实样本")
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.evidence.tracking_method || qsTr("等待导入日志并计算"); color: theme.dim }
                Repeater { model: root.rateMetrics
                    Label { required property var modelData; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.family: theme.monoFamily; color: theme.cyan; text: modelData.axis + " · " + root.displayNumber(modelData.tracking_score,1) + "/100 · RMS误差 " + root.displayNumber(modelData.active_rmse,2) + " / 目标RMS " + root.displayNumber(modelData.active_target_rms,2) + " " + modelData.unit + " · " + modelData.active_samples + qsTr(" 动作样本 · ") + root.displayNumber(modelData.score_start_seconds,2) + "–" + root.displayNumber(modelData.score_end_seconds,2) + " s" }
                }
            }
            HQAICard {
                objectName: "aiHardwareReportCard"; Layout.fillWidth: true; visible: root.logAnalysisOnly
                heading: qsTr("硬件与运行状态 · 全日志")
                GridLayout {
                    Layout.fillWidth: true; columns: pageBody.width < 700 ? 1 : 3
                    Repeater {
                        model: [
                            {title:qsTr("CPU 负载"), data:root.hardwareReport.cpu_load || ({})},
                            {title:qsTr("内存"), data:root.hardwareReport.memory || ({})},
                            {title:qsTr("循环频率"), data:root.hardwareReport.loop_rate_hz || ({})},
                            {title:qsTr("最长循环耗时"), data:root.hardwareReport.loop_max_us || ({})},
                            {title:qsTr("内部错误"), data:root.hardwareReport.internal_errors || ({})},
                            {title:qsTr("IMU 削波"), data:root.hardwareReport.imu_clipping || ({})}]
                        ColumnLayout {
                            id: hardwareMetric
                            required property var modelData
                            Layout.fillWidth: true; Layout.preferredWidth: 1
                            Label { text: hardwareMetric.modelData.title; color: theme.dim }
                            Mono { text: root.displayNumber(hardwareMetric.modelData.data.mean,2) + " " + (hardwareMetric.modelData.data.unit || ""); color: theme.cyan; font.pointSize: 16 }
                            Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.dim; font.pointSize: 8; text: (hardwareMetric.modelData.data.field || qsTr("未记录")) + " · max " + root.displayNumber(hardwareMetric.modelData.data.max,2) + " · " + root.displayNumber(hardwareMetric.modelData.data.peak_seconds,2) + " s" }
                        }
                    }
                }
                Repeater { model: root.hardwareReport.imu_logging || []; Label { required property var modelData; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.dim; text: modelData.field + " · " + root.displayNumber(modelData.logged_rate_hz,1) + qsTr(" Hz 日志均值，含间隙；不是物理采样率") } }
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.dim; text: root.hardwareReport.scope || qsTr("导入日志后显示真实统计；未记录显示未知。") }
            }
            HQAICard {
                Layout.fillWidth: true; visible: !root.logAnalysisOnly && logParser.parseComplete; heading: qsTr("调参有效区间与碰触排除")
                RowLayout { Layout.fillWidth: true
                    HQAIInput { id: analysisBegin; objectName: "aiAnalysisBegin"; Layout.fillWidth: true; enabled: !root.contextLocked; placeholderText: qsTr("开始 / s（空=全日志）"); onTextChanged: { if (root.viewReady && !root.restoringRecord) root.rangeDirty = true; root.contextChanged() }
                        onEditingFinished: if (!root.contextLocked && logParser.parseComplete) root.applyAnalysisWindow() }
                    HQAIInput { id: analysisEnd; objectName: "aiAnalysisEnd"; Layout.fillWidth: true; enabled: !root.contextLocked; placeholderText: qsTr("结束 / s（空=全日志）"); onTextChanged: { if (root.viewReady && !root.restoringRecord) root.rangeDirty = true; root.contextChanged() }
                        onEditingFinished: if (!root.contextLocked && logParser.parseComplete) root.applyAnalysisWindow() }
                }
                HQAIInput { id: manualExclusions; Layout.fillWidth: true; enabled: !root.contextLocked; placeholderText: qsTr("排除碰触区间，例如 60-65;120-123，单位秒"); onTextChanged: { if (root.viewReady && !root.restoringRecord) root.rangeDirty = true; root.contextChanged() }
                    onEditingFinished: if (!root.contextLocked && logParser.parseComplete) root.applyAnalysisWindow() }
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.dim; text: qsTr("自动排除已报告未解锁 / 着陆，以及低于 0.5m 的离地高度代理。空中触碰无法可靠自动识别，可指定排除区间；故障诊断仍保留全日志。") }
                HQAIActionButton { text: qsTr("计算有效区间"); enabled: !root.contextLocked && !logParser.parsing; onClicked: root.applyAnalysisWindow() }
                Label { id: windowError; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.red }
            }
            GridLayout {
                visible: !root.logAnalysisOnly
                Layout.fillWidth: true; columns: pageBody.width < 850 ? 1 : 2; columnSpacing: 14; rowSpacing: 14
                HQAICard {
                    Layout.fillWidth: true; Layout.preferredWidth: pageBody.width * 0.65; Layout.alignment: Qt.AlignTop
                    heading: qsTr("角速度跟踪 · 目标 vs 实际")
                    HQAIComparisonDeck { objectName: "aiRateComparison"; Layout.fillWidth: true; parser: root.displayParser; rangeEditable: !root.flightCaptureOnly && !root.contextLocked; beginText: root.flightCaptureOnly ? "" : analysisBegin.text; endText: root.flightCaptureOnly ? "" : analysisEnd.text; onRangeEdited: function(begin, end) { analysisBegin.text = begin; analysisEnd.text = end; root.applyAnalysisWindow() } }
                    Label { text: qsTr("RATE 基线诊断 · 本地实测"); color: theme.amber; font.bold: true }
                    Repeater {
                        model: root.rateMetrics
                        ColumnLayout {
                            id: baselineAxis
                            required property var modelData
                            readonly property var measured: modelData.temporal_analysis || ({})
                            Layout.fillWidth: true
                            Mono { text: baselineAxis.modelData.axis + "   σ比 " + root.displayNumber(baselineAxis.measured.std_amplitude_ratio, 2)
                                + "   滞后 " + root.displayNumber(baselineAxis.measured.lag_ms, 0) + " ms"
                                + "   超调 " + root.displayNumber(baselineAxis.measured.overshoot_percent, 1) + "%" }
                            Mono { text: "RMSE " + root.displayNumber(baselineAxis.measured.rmse, 2) + " " + baselineAxis.modelData.unit
                                + "   误差峰 " + root.displayNumber(baselineAxis.measured.dominant_error_hz, 1) + " Hz"; color: theme.cyan; font.pointSize: 9 }
                            Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: baselineAxis.measured.baseline || qsTr("尚未计算时序指标"); color: theme.text; font.pointSize: 9 }
                            Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: (baselineAxis.measured.evidence_strength || "") + " · " + (baselineAxis.measured.scope || "") + " · "
                                + root.displayNumber(baselineAxis.measured.start_seconds, 2) + "–" + root.displayNumber(baselineAxis.measured.end_seconds, 2) + " s"; color: theme.dim; font.pointSize: 8 }
                            Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: qsTr("缺少增强项：") + ((baselineAxis.measured.missing_enhancements || []).join("、") || qsTr("见 AI 分析中的滤波 / RPM 核对")); color: theme.dim; font.pointSize: 8 }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: theme.border }
                    Label { text: qsTr("PID 贡献 · 平均绝对幅值占比"); color: theme.dim; font.pointSize: 9 }
                    GridLayout { Layout.fillWidth: true; columns: 3; columnSpacing: 18
                        Repeater {
                            model: root.evidence.pid_contributions || []
                            ColumnLayout {
                                id: pidRow; required property var modelData
                                Layout.fillWidth: true; Layout.preferredWidth: 1
                                Item { Layout.fillWidth: true; Layout.preferredHeight: 7
                                    Rectangle { id: pTerm; height: 7; width: parent.width * Number(pidRow.modelData.p || 0); color: theme.cyan }
                                    Rectangle { id: iTerm; x: pTerm.width; height: 7; width: parent.width * Number(pidRow.modelData.i || 0); color: theme.amber }
                                    Rectangle { x: pTerm.width + iTerm.width; height: 7; width: parent.width * Number(pidRow.modelData.d || 0); color: theme.violet }
                                }
                                Mono { text: pidRow.modelData.axis + "  I " + (pidRow.modelData.i === null ? "--" : (Number(pidRow.modelData.i) * 100).toFixed(0) + "%"); font.pointSize: 8; color: theme.dim }
                            }
                        }
                    }
                    Label { text: qsTr("青 P  /  琥珀 I  /  紫 D · 不代表控制效能"); color: theme.dim; font.pointSize: 8 }
                    Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; visible: (root.evidence.pid_contributions || []).length === 0; text: qsTr("日志未提供 P/I/D 分项，不能计算贡献占比。"); color: theme.dim; font.pointSize: 8 }
                }
                HQAICard {
                    Layout.fillWidth: true; Layout.preferredWidth: pageBody.width * 0.35; Layout.alignment: Qt.AlignTop
                    heading: qsTr("AI 建议改动")
                    Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.controller.proposals.length ? qsTr("%1 项有效差异 · 滑块选择").arg(root.controller.proposals.length) : root.controller.busy ? qsTr("正在分析…") : qsTr("暂无有效改动；不代表飞机无需调参。"); color: theme.dim; font.pointSize: 9 }
                    ScrollView {
                        id: recommendationScroll
                        Layout.fillWidth: true; Layout.preferredHeight: Math.min(390, recommendationList.implicitHeight + 4)
                        contentWidth: availableWidth
                        clip: true
                        ColumnLayout {
                            id: recommendationList; width: recommendationScroll.availableWidth; spacing: 12
                            Repeater {
                                model: root.controller.proposals
                                ColumnLayout {
                                    id: suggestion; required property var modelData; Layout.fillWidth: true; spacing: 5
                                    Mono { Layout.fillWidth: true; text: suggestion.modelData.name; font.bold: true; elide: Text.ElideRight }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Mono { text: root.displayParameter(suggestion.modelData.before); color: theme.dim }
                                        Mono { text: "→"; color: theme.dim }
                                        Mono { Layout.fillWidth: true; text: root.displayParameter(suggestion.modelData.value) + " " + suggestion.modelData.unit; color: suggestion.modelData.acknowledged ? theme.green : theme.violet; wrapMode: Text.WordWrap }
                                        HQAIToggle { Accessible.name: suggestion.modelData.name + qsTr("建议选择"); checked: root.selectedProposals.indexOf(suggestion.modelData.name) >= 0; enabled: !root.contextLocked && !suggestion.modelData.applied && (root.controller.logOnly || suggestion.modelData.blocked === ""); onClicked: root.selectProposal(suggestion.modelData.name, checked) }
                                    }
                                    Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: suggestion.modelData.reason; font.pointSize: 9; color: theme.dim }
                                    Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: suggestion.modelData.acknowledged ? qsTr("已获飞控回执") : suggestion.modelData.applied ? qsTr("已提交，结果请复核") : root.controller.logOnly ? qsTr("日志候选值 · 切换到飞行调参后核对") : suggestion.modelData.blocked; visible: text !== ""; color: suggestion.modelData.acknowledged ? theme.green : theme.dim; font.pointSize: 8 }
                                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: theme.border }
                                }
                            }
                        }
                    }
                    HQAIActionButton {
                        objectName: "aiApplySelectedButton"; Layout.fillWidth: true; primary: true
                        text: root.logAnalysisOnly ? qsTr("切换到飞行调参") : qsTr("一键写入所选")
                        enabled: root.logAnalysisOnly || (!root.contextLocked && root.pendingSelectionCount > 0 && !!root.activeVehicle)
                        onClicked: if (root.logAnalysisOnly) root.switchWorkspace(false); else root.confirmSelected()
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        HQAIActionButton { Layout.fillWidth: true; text: qsTr("保存快照"); enabled: !root.contextLocked && !!root.activeVehicle; onClicked: root.controller.saveSnapshot() }
                        HQAIActionButton { Layout.fillWidth: true; text: qsTr("回滚审核"); danger: true; enabled: !root.contextLocked && root.controller.rollbackAvailable && !!root.activeVehicle; onClicked: { if (root.controller.prepareRollback()) { root.logAnalysisOnly = false; root.confirmSelected() } } }
                    }
                    Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.dim; font.pointSize: 8; text: root.logAnalysisOnly ? qsTr("日志页保持只读。切换调参可保留本次日志与候选建议。") : !root.activeVehicle ? qsTr("未连接飞控：可分析日志；写入与快照需连接并核对目标。") : qsTr("写入需未解锁、硬件核对、风险确认与逐项回执。范围校验不代表安全。") }
                    Label { Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; text: root.controller.backupPath; visible: text !== ""; color: theme.dim; font.pointSize: 8 }
                }
            }
            HQAICard {
                objectName: "aiStepResponseCard"; Layout.fillWidth: true; visible: !root.logAnalysisOnly && root.rateMetrics.length > 0
                heading: qsTr("阶跃响应 · 频域估计")
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: theme.dim; font.pointSize: 9; text: qsTr("由真实目标/实际窗口估计：灰线为各窗口、青线为均值、琥珀虚线为单位目标 1。仅估计 0.5s，不代表最终稳态或已完成整定；激励 / 相干性不足显示未知。") }
                GridLayout {
                    Layout.fillWidth: true; columns: pageBody.width < 800 ? 1 : 3; columnSpacing: 12
                    Repeater {
                        model: root.rateMetrics
                        ColumnLayout {
                            id: stepAxis
                            required property var modelData
                            readonly property var plots: (modelData.temporal_analysis || {}).response_plots || ({})
                            readonly property var mean: plots.step_mean || []
                            readonly property var curves: plots.step_curves || []
                            Layout.fillWidth: true; Layout.preferredWidth: 1
                            Mono { text: stepAxis.modelData.axis + " · " + (stepAxis.plots.step_windows || 0) + qsTr(" 估计窗") }
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 190; color: theme.background; border.color: theme.border
                                Canvas {
                                    id: stepCanvas
                                    anchors.fill: parent; anchors.margins: 12
                                    onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
                                    onPaint: {
                                        const ctx = getContext("2d"); ctx.reset()
                                        if (stepAxis.mean.length < 2) return
                                        let minimum = 0, maximum = 1.5
                                        for (const curve of stepAxis.curves.concat([stepAxis.mean])) for (const point of curve) {
                                            minimum = Math.min(minimum, point.response); maximum = Math.max(maximum,point.response)
                                        }
                                        const span = Math.max(0.1,maximum-minimum)
                                        function draw(points,color,lineWidth) {
                                            ctx.strokeStyle = color; ctx.lineWidth = lineWidth; ctx.setLineDash([]); ctx.beginPath()
                                            for (let i=0;i<points.length;++i) {
                                                const x=points[i].seconds/0.5*stepCanvas.width, y=stepCanvas.height-(points[i].response-minimum)/span*stepCanvas.height
                                                if (i) ctx.lineTo(x,y); else ctx.moveTo(x,y)
                                            }
                                            ctx.stroke()
                                        }
                                        for (const curve of stepAxis.curves) draw(curve,"#506070",0.7)
                                        ctx.strokeStyle=theme.amber; ctx.lineWidth=1; ctx.setLineDash([4,3]); ctx.beginPath()
                                        const unityY=height-(1-minimum)/span*height; ctx.moveTo(0,unityY);ctx.lineTo(width,unityY);ctx.stroke()
                                        draw(stepAxis.mean,theme.cyan,2)
                                        ctx.fillStyle=theme.dim;ctx.font="10px \'" + ScreenTools.normalFontFamily + "\'";ctx.fillText("1",0,Math.max(12,unityY-3))
                                        ctx.fillText("0 s",0,height-2);ctx.fillText("0.5 s",Math.max(0,width-35),height-2)
                                    }
                                }
                                Label { anchors.centerIn: parent; visible: stepAxis.mean.length < 2; text: qsTr("阶跃估计未知"); color: theme.dim }
                            }
                            Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pointSize: 8; color: theme.dim; text: stepAxis.plots.step_status || qsTr("尚未计算") }
                        }
                    }
                }
            }
            HQAICard {
                objectName: "aiSpectrumEvidenceCard"; Layout.fillWidth: true; visible: !root.logAnalysisOnly && root.rateMetrics.length > 0
                heading: qsTr("PID 时频谱 · 真实日志窗口")
                RowLayout {
                    Layout.fillWidth: true
                    HQAICombo { id: spectrumSource; objectName: "aiSpectrumSource"; model: [qsTr("实际角速率"),qsTr("目标角速率"),qsTr("跟踪误差")]; Layout.preferredWidth: 200 }
                    Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pointSize: 9; color: theme.dim; text: qsTr("512 点 Hann 窗、50% 重叠；dB 相对 1 原单位²/Hz。蓝=弱、橙红=强。不需要 RPM，不能把控制信号频谱直接当电机共振。") }
                }
                Repeater {
                    model: root.rateMetrics
                    ColumnLayout {
                        id: spectrumAxis
                        required property var modelData
                        readonly property var measured: modelData.temporal_analysis || ({})
                        readonly property var plots: measured.response_plots || ({})
                        readonly property var frames: plots.spectrogram || []
                        readonly property string key: ["actual_db","target_db","error_db"][spectrumSource.currentIndex]
                        Layout.fillWidth: true
                        Mono { text: spectrumAxis.modelData.axis + " · " + root.displayNumber(spectrumAxis.measured.start_seconds,2) + "–" + root.displayNumber(spectrumAxis.measured.end_seconds,2) + " s · Δf " + root.displayNumber(spectrumAxis.plots.frequency_resolution_hz,2) + " Hz" }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 190; color: theme.background; border.color: theme.border
                            Canvas {
                                id: heatmap
                                anchors.fill: parent; anchors.margins: 16
                                onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
                                Connections { target: spectrumSource; function onCurrentIndexChanged() { heatmap.requestPaint() } }
                                onPaint: {
                                    const ctx=getContext("2d");ctx.reset()
                                    const frames=spectrumAxis.frames
                                    if (frames.length<1) return
                                    let low=Infinity,high=-Infinity
                                    for (const frame of frames) for (const value of frame[spectrumAxis.key]) { low=Math.min(low,value);high=Math.max(high,value) }
                                    const span=Math.max(1,high-low), w=Math.max(1,width-48),h=Math.max(1,height-25)
                                    const first=Number(spectrumAxis.measured.start_seconds),last=Number(spectrumAxis.measured.end_seconds),timeSpan=Math.max(0.001,last-first)
                                    function color(t) {
                                        t=Math.max(0,Math.min(1,t))
                                        const stops=[[29,32,160],[113,151,235],[235,201,155],[166,38,39]]
                                        const n=Math.min(2,Math.floor(t*3)),f=t*3-n,a=stops[n],b=stops[n+1]
                                        return "rgb("+Math.round(a[0]+(b[0]-a[0])*f)+","+Math.round(a[1]+(b[1]-a[1])*f)+","+Math.round(a[2]+(b[2]-a[2])*f)+")"
                                    }
                                    for (let i=0;i<frames.length;++i) {
                                        const values=frames[i][spectrumAxis.key]
                                        const x=(frames[i].time-first)/timeSpan*w+42
                                        const next=i+1<frames.length ? (frames[i+1].time-first)/timeSpan*w+42 : w+42
                                        for (let bin=0;bin<values.length;++bin) {
                                            ctx.fillStyle=color((values[bin]-low)/span)
                                            ctx.fillRect(x,h-(bin+1)/values.length*h,Math.max(1,next-x),Math.max(1,h/values.length+0.5))
                                        }
                                    }
                                    ctx.fillStyle=theme.dim;ctx.font="11px \'" + ScreenTools.normalFontFamily + "\'"
                                    ctx.fillText("0 Hz",0,h);ctx.fillText(Number(spectrumAxis.plots.nyquist_hz).toFixed(0)+" Hz",0,12)
                                    ctx.fillText(first.toFixed(1)+" s",42,height-1);ctx.fillText(last.toFixed(1)+" s",Math.max(50,width-60),height-1)
                                    for (let i=0;i<100;++i) {ctx.fillStyle=color(i/99);ctx.fillRect(80+i*(w-100)/100,h+5,Math.max(1,(w-100)/100),5)}
                                    ctx.fillStyle=theme.dim;ctx.fillText(low.toFixed(1)+" dB",80,h+22);ctx.fillText(high.toFixed(1)+" dB",Math.max(90,width-125),h+22)
                                }
                            }
                            Label { anchors.centerIn: parent; visible: spectrumAxis.frames.length === 0; text: qsTr("连续样本 / 激励不足，时频谱未知"); color: theme.dim }
                        }
                    }
                }
            }
            HQAICard {
                Layout.fillWidth: true; heading: qsTr("分析结论与待补充信息"); visible: root.controller.summary !== "" || root.controller.questions !== ""
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.controller.summary; font.pointSize: 10 }
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.controller.questions; color: theme.dim; font.pointSize: 9 }
            }
            HQAICard {
                Layout.fillWidth: true; heading: qsTr("调参历史 · 本次会话")
                GridLayout {
                    Layout.fillWidth: true; columns: pageBody.width >= 900 ? 3 : 1; columnSpacing: 20
                    Repeater {
                        model: root.controller.history.slice(0, 6)
                        ColumnLayout {
                            id: historyRow
                            required property var modelData; Layout.fillWidth: true; spacing: 3
                            Mono { text: new Date(historyRow.modelData.time).toLocaleTimeString(Qt.locale(), "HH:mm:ss"); font.pointSize: 9; color: theme.amber }
                            Label { Layout.fillWidth: true; text: historyRow.modelData.action; font.pointSize: 9; font.bold: true }
                            Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: historyRow.modelData.detail; font.pointSize: 8; color: theme.dim }
                        }
                    }
                }
                Label { visible: root.controller.history.length === 0; text: qsTr("导入、分析、快照与真实回执会在此记录。"); color: theme.dim; font.pointSize: 9 }
            }
            HQAIActionButton { text: extraTraces.visible ? qsTr("收起其它日志字段") : qsTr("查看振动与其它日志字段"); visible: logParser.parseComplete; onClicked: extraTraces.visible = !extraTraces.visible }
            HQAICard { id: extraTraces; objectName: "aiRawEvidenceCard"; Layout.fillWidth: true; visible: false; heading: qsTr("振动、姿态与原始字段"); HQAITracePreview { Layout.fillWidth: true; parser: root.displayParser } }
            Item { Layout.preferredHeight: 14 }
        }
    }
}
