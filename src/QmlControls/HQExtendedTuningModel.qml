import QtQuick
import QtQuick.Controls

import QGroundControl

// Shared draft/confirmation policy for the fixed setup page and the flight tool.
Item {
    id: root

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var controllerOverride: null
    property int parameterRevision: 0
    property string statusText: ""
    property int confirmationTimeoutMs: 60000
    readonly property var controller: controllerOverride || controllerLoader.item
    readonly property bool isPX4: !!vehicle && vehicle.px4Firmware
    readonly property bool parametersReady: _parametersAvailable(controller, vehicle)
    readonly property bool canWrite: _writableTarget(controller, vehicle)
    readonly property int pendingCount: _drafts.length
    readonly property bool _currentTarget: _matchesTarget(controller, vehicle)
    property var _drafts: []
    property int _sessionRevision: 0
    property int _draftRevision: 0
    property bool _componentReady: false

    Component {
        id: controllerComponent
        FactPanelController { }
    }
    Loader {
        id: controllerLoader
        active: false
        sourceComponent: controllerComponent
        onLoaded: root.parameterRevision++
    }

    function _clearDrafts() {
        _drafts = []
        _draftRevision++
    }

    function _invalidateSession(clearDrafts) {
        _sessionRevision++
        parameterRevision++
        if (clearDrafts) _clearDrafts()
    }

    function _rebuildController() {
        if (!_componentReady) return
        controllerLoader.active = false
        if (!controllerOverride && vehicle === QGroundControl.multiVehicleManager.activeVehicle && vehicle) {
            controllerLoader.active = true
        }
    }

    function _matchesTarget(currentController, target) {
        return !!target && !!currentController && currentController.vehicle === target
                && target === QGroundControl.multiVehicleManager.activeVehicle
    }

    function _parametersAvailable(currentController, target) {
        const manager = target ? target.parameterManager : null
        return _matchesTarget(currentController, target) && !!manager && manager.parametersReady === true
    }

    function _writableTarget(currentController, target) {
        const manager = target ? target.parameterManager : null
        const link = target ? target.vehicleLinkManager : null
        return _parametersAvailable(currentController, target) && !target.armed && !target.flying
                && !!link && !link.communicationLost && !manager.pendingWrites
    }

    function _showReadyStatus() {
        if (!_parametersAvailable(controller, vehicle)) return
        statusText = _drafts.length > 0
                ? qsTr("飞控参数已就绪，本页有 %1 项暂存修改；请检查后确认提交。").arg(_drafts.length)
                : qsTr("飞控参数已就绪，可在本页暂存修改。")
    }

    function parameterFact(names) {
        const revision = parameterRevision
        const currentController = controller
        const target = vehicle
        if (!_matchesTarget(currentController, target) || !names) return null
        for (let i = 0; i < names.length; ++i) {
            if (currentController.parameterExists(-1, names[i])) {
                return currentController.getParameterFact(-1, names[i], false)
            }
        }
        return null
    }

    function _ownsFact(fact) {
        const currentController = controller
        const target = vehicle
        return _matchesTarget(currentController, target) && !!fact && !!fact.name
                && currentController.parameterExists(fact.componentId, fact.name)
                && currentController.getParameterFact(fact.componentId, fact.name, false) === fact
    }

    function _draftFor(fact) {
        for (let i = 0; i < _drafts.length; ++i) {
            if (_drafts[i].fact === fact) return _drafts[i]
        }
        return null
    }

    function textFor(fact) {
        const revision = parameterRevision
        const draft = _draftFor(fact)
        return draft ? draft.text : (fact ? fact.valueString : "")
    }

    function isChanged(fact) { return !!_draftFor(fact) }

    function _number(text) {
        const normalized = String(text).trim().toLowerCase()
        if (normalized === "true") return 1
        if (normalized === "false") return 0
        return Number(normalized)
    }

    function errorFor(fact, text) {
        if (!_ownsFact(fact)) return qsTr("参数已不可用，请重新读取。")
        if (fact.readOnly) return qsTr("此参数只读，不能修改。")
        if (typeof fact.validate !== "function") return qsTr("参数缺少校验信息，禁止提交。")
        const input = String(text)
        const validation = fact.validate(input, false)
        if (validation) return validation
        if (!fact.typeIsString && (!input.trim().length || !isFinite(_number(input)))) {
            return qsTr("请输入有效数值。")
        }
        if (fact.enumValues && fact.enumValues.length > 0) {
            const value = _number(input)
            let supported = false
            for (let i = 0; i < fact.enumValues.length; ++i) {
                if (Number(fact.enumValues[i]) === value) supported = true
            }
            if (!supported) return qsTr("当前固件不支持此枚举值，请从选项中选择。")
        }
        return ""
    }

    function stage(fact, text) {
        if (!_ownsFact(fact) || fact.readOnly) {
            statusText = errorFor(fact, text)
            return false
        }
        const input = String(text)
        const previous = _draftFor(fact)
        const same = input === fact.valueString || (!fact.typeIsString && input.trim().length > 0
                     && isFinite(_number(input)) && _number(input) === _number(fact.valueString))
        if (!previous && same) return true
        if (previous && previous.text === input) return true
        const next = _drafts.filter(function(row) { return row.fact !== fact })
        if (!same) {
            next.push({fact: fact, name: fact.name, componentId: fact.componentId, text: input,
                       baseRawValue: previous ? previous.baseRawValue : fact.rawValue})
        }
        _drafts = next
        _draftRevision++
        statusText = qsTr("修改暂存于本页，尚未提交飞控。")
        return true
    }

    function _snapshot() {
        const currentController = controller
        const target = vehicle
        if (!_matchesTarget(currentController, target) || !target.parameterManager) return null
        return {vehicle: target, controller: currentController, parameterManager: target.parameterManager,
                session: _sessionRevision, draftRevision: _draftRevision, createdAt: Date.now(),
                rows: _drafts.slice(0)}
    }

    function _planError(plan, writing) {
        const currentController = controller
        const target = vehicle
        const manager = target ? target.parameterManager : null
        const link = target ? target.vehicleLinkManager : null
        if (!plan || plan.vehicle !== target || plan.controller !== currentController
                || plan.session !== _sessionRevision || plan.draftRevision !== _draftRevision
                || !_matchesTarget(currentController, target) || plan.parameterManager !== manager) {
            return qsTr("目标或草稿已变化，本次确认已失效，请重新检查。")
        }
        if (Date.now() - plan.createdAt >= confirmationTimeoutMs) {
            return qsTr("确认已过期，请重新检查后提交。")
        }
        if (!link || link.communicationLost) {
            return qsTr("飞控通信中断，请恢复连接后重试。")
        }
        if (writing && !_writableTarget(currentController, target)) {
            return qsTr("请等待参数就绪，并确保飞控未解锁、未飞行且无待完成写入。")
        }
        for (let i = 0; writing && i < plan.rows.length; ++i) {
            const row = plan.rows[i]
            const error = errorFor(row.fact, row.text)
            if (error) return row.name + ": " + error
            if (row.fact.rawValue !== row.baseRawValue) {
                return qsTr("参数 %1 已被其他操作更改，请重新读取后再调参。").arg(row.name)
            }
        }
        return ""
    }

    function _applyPlan(plan) {
        // Validate every row before any Fact assignment; MAVLink writes themselves are asynchronous.
        const error = _planError(plan, true)
        if (error) { statusText = error; return false }
        for (let i = 0; i < plan.rows.length; ++i) plan.rows[i].fact.value = plan.rows[i].text
        _clearDrafts()
        parameterRevision++
        statusText = qsTr("已向飞控提交 %1 项参数；请等待参数回读确认。").arg(plan.rows.length)
        return true
    }

    function requestWrite(owner) {
        if (!pendingCount) { statusText = qsTr("当前没有待提交的修改。"); return false }
        const plan = _snapshot()
        const error = _planError(plan, true)
        if (error) { statusText = error; return false }
        QGroundControl.showMessageDialog(owner || root, qsTr("确认写入参数"),
            qsTr("即将向当前飞控提交 %1 项修改。请确认参数和飞机状态。").arg(plan.rows.length),
            Dialog.Yes | Dialog.No, function() { root._applyPlan(plan) })
        return true
    }

    function _reload(plan) {
        const error = _planError(plan, false)
        if (error) { statusText = error; return false }
        if (!plan.parameterManager || typeof plan.parameterManager.refreshAllParameters !== "function") {
            statusText = qsTr("当前飞控不支持重新读取参数。")
            return false
        }
        _invalidateSession(true)
        statusText = qsTr("已请求重新读取飞控参数，等待读取完成。")
        plan.parameterManager.refreshAllParameters()
        return true
    }

    function requestReload(owner) {
        const plan = _snapshot()
        const error = _planError(plan, false)
        if (error) { statusText = error; return false }
        if (!pendingCount) return _reload(plan)
        QGroundControl.showMessageDialog(owner || root, qsTr("重新读取参数"),
            qsTr("重新读取将丢弃本页 %1 项未提交修改，是否继续？").arg(pendingCount),
            Dialog.Yes | Dialog.No, function() { root._reload(plan) })
        return true
    }

    onVehicleChanged: {
        _invalidateSession(true)
        statusText = vehicle ? qsTr("正在准备当前飞控参数。") : qsTr("等待飞控连接。")
        _showReadyStatus()
        Qt.callLater(_rebuildController)
    }
    onControllerOverrideChanged: { _invalidateSession(true); Qt.callLater(_rebuildController) }
    onControllerChanged: _invalidateSession(true)
    onParametersReadyChanged: _showReadyStatus()
    Component.onCompleted: { _componentReady = true; _rebuildController(); _showReadyStatus() }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged() { root._invalidateSession(true); Qt.callLater(root._rebuildController) }
    }
    Connections {
        target: root.controller
        ignoreUnknownSignals: true
        function onMissingParametersAvailable() { root.parameterRevision++ }
    }
    Connections {
        target: root.vehicle ? root.vehicle.parameterManager : null
        function onParametersReadyChanged() {
            root.parameterRevision++
            if (root._parametersAvailable(root.controller, root.vehicle)) root._showReadyStatus()
            else root._invalidateSession(false)
        }
    }
    Connections {
        target: root.vehicle ? root.vehicle.vehicleLinkManager : null
        function onCommunicationLostChanged() {
            if (root.vehicle && root.vehicle.vehicleLinkManager.communicationLost) root._invalidateSession(false)
        }
    }
    Connections {
        target: root.vehicle
        function onArmedChanged() { if (root.vehicle && root.vehicle.armed) root._invalidateSession(false) }
        function onFlyingChanged() { if (root.vehicle && root.vehicle.flying) root._invalidateSession(false) }
    }
}
