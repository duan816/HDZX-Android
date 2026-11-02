import QtQuick

QtObject {
    id: root
    property var vehicle: null
    property bool waitingForHeartbeat: false
    property bool connectionFailed: false
    property string connectionFailureText: ""

    readonly property bool connected: !!vehicle && !vehicle.isOfflineEditingVehicle
    readonly property var health: connected ? vehicle.healthAndArmingCheckReport : null
    readonly property bool communicationLost: connected && !!vehicle.vehicleLinkManager
                                              && vehicle.vehicleLinkManager.communicationLost
    readonly property bool initializing: connected && !communicationLost && !vehicle.initialConnectComplete
    readonly property bool healthSupported: !!health && health.supported
    readonly property bool ready: !!(connected && (healthSupported ? health.canArm
        : vehicle.readyToFlyAvailable ? vehicle.readyToFly
        : vehicle.allSensorsHealthy && !!vehicle.autopilotPlugin && vehicle.autopilotPlugin.setupComplete))
    readonly property bool persistentWarnings: connected && vehicle.recentWarnings
        ? Array.from(vehicle.recentWarnings).some(row => row.persistent) : false
    readonly property bool warnings: (healthSupported && health.hasWarningsOrErrors) || persistentWarnings
    readonly property bool blocked: healthSupported && !health.canArm
    readonly property bool healthErrors: {
        if (!healthSupported || !health.hasWarningsOrErrors || !health.problemsForCurrentMode) return false
        const problems = health.problemsForCurrentMode
        for (let i = 0; i < problems.count; i++) {
            if (problems.get(i).severity === "error") return true
        }
        return false
    }
    readonly property string stateKey: !connected ? (waitingForHeartbeat ? "connecting" : "disconnected")
        : communicationLost ? "lost" : blocked || healthErrors ? "blocked" : initializing ? "connecting"
        : warnings ? "warning" : vehicle.armed ? "armed" : ready ? "ready" : "not-ready"
    readonly property string tone: stateKey === "disconnected" || stateKey === "lost" || stateKey === "blocked"
        ? "danger" : stateKey === "connecting" ? "info"
        : stateKey === "warning" || stateKey === "not-ready" ? "warning" : "success"
    readonly property color accent: tone === "danger" ? "#ff697a" : tone === "warning" ? "#f4c45b"
        : tone === "info" ? "#66c9ff" : "#64e6b0"
    readonly property string symbol: tone === "danger" ? "cross" : tone === "warning" ? "alert"
        : tone === "info" ? "dots" : "check"
    readonly property string label: !connected ? (waitingForHeartbeat ? qsTr("正在连接")
        : connectionFailed ? qsTr("未收到飞控") : qsTr("未连接"))
        : communicationLost ? qsTr("通信中断")
        : vehicle.flying ? qsTr("飞行中") : vehicle.landing ? qsTr("降落中")
        : vehicle.armed ? qsTr("已解锁") : blocked ? qsTr("禁止解锁")
        : healthErrors ? qsTr("检查异常") : initializing ? qsTr("正在初始化")
        : ready ? (warnings ? qsTr("就绪 · 有告警") : qsTr("准备就绪")) : qsTr("尚未就绪")
    readonly property string detail: !connected ? (waitingForHeartbeat ? qsTr("等待飞控心跳")
        : connectionFailed ? connectionFailureText : qsTr("点击选择连接"))
        : communicationLost ? qsTr("遥测失联 · 检查链路")
        : blocked ? qsTr("检查未通过 · 点击查看")
        : healthErrors ? qsTr("检查报告错误 · 点击查看")
        : initializing ? qsTr("读取参数与飞控状态")
        : warnings ? qsTr("有待处理检查 · 点击查看")
        : vehicle.armed ? qsTr("动力已使能 · 点击查看")
        : ready ? qsTr("检查通过 · 点击查看") : qsTr("解锁前检查 · 点击查看")
}
