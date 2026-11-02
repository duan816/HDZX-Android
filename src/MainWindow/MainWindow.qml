import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import QtCore

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.PlanView
import QGroundControl.Toolbar

/// @brief Native QML top level window
/// All properties defined here are visible to all QML pages.
ApplicationWindow {
    id:         mainWindow
    property string _pendingSettingsPage: ""
    property string _pendingVehiclePage: ""
    property int _pendingVehicleComponent: -1
    property var _pendingPageVehicle: null
    property alias hdzxConnectionAttempt: connectionAttempt
    HDZXConnectionAttempt {
        id: connectionAttempt
        objectName: "hdzxConnectionAttempt"
        vehicleManager: QGroundControl.multiVehicleManager
    }

    function connectLinkWithStatus(configuration) {
        connectionAttempt.begin(configuration)
        QGroundControl.linkManager.createConnectedLink(configuration)
        Qt.callLater(connectionAttempt.checkStarted)
    }
    readonly property real hdzxRailWidth: ScreenTools.isMobile ? 68 * ScreenTools.mobileUiScale : 88
    property string hdzxWorkspace: "flight"

    property int hdzxNavigationMotionMode: Math.max(0, Math.min(2,
        Number(QGroundControl.loadGlobalSetting("HDZX/WorkspaceMotionV2", "0")) || 0))
    readonly property bool hdzxNavigationAnimationsEnabled: hdzxNavigationMotionMode !== 2
    property int hdzxToolSlot: 0
    readonly property var toolDrawerLoader: hdzxToolSlot === 0 ? toolLoaderA : toolLoaderB

    function setNavigationMotionMode(mode) {
        hdzxNavigationMotionMode = Math.max(0, Math.min(2, mode))
        QGroundControl.saveGlobalSetting("HDZX/WorkspaceMotionV2", String(hdzxNavigationMotionMode))
    }
    HQRebootConnectionDialog { parent:Overlay.overlay }
    readonly property bool flyViewToolsPaused: !flyView.visible
    visible:    true
    font.family: ScreenTools.normalFontFamily
    font.pointSize: ScreenTools.defaultFontPointSize
    // The special casing for android prevents white bars from showing up on the edges of the screen with newer android versions
    flags:      Qt.Window | (ScreenTools.isAndroid ? Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint : 0)
                | ((typeof hdzxNoFocusReview !== "undefined" && hdzxNoFocusReview) ? Qt.WindowDoesNotAcceptFocus : 0)

    // Qt 6.9+ auto-sets ApplicationWindow padding to the display safe-area insets on mobile,
    // which insets our full-bleed content and leaves a blank strip along the screen edge.
    // QGC draws edge-to-edge and manages its own insets, so zero the padding.
    topPadding:    0
    bottomPadding: 0
    leftPadding:   0
    rightPadding:  0

    function showStartupPrompt() {
        if ((ScreenTools.isAndroid || ScreenTools.isFakeMobile)
                && !QGroundControl.settingsManager.appSettings.mobileUiPresetChosen.rawValue) {
            mobileDisplayPresetDialog.open()
        } else if (hqStartupSettings.disclaimerAccepted) {
            firstRunPromptManager.nextPrompt()
        } else {
            disclaimerDialog.open()
        }
    }

    Loader {
        id: startupAnimationLoader
        objectName: "hdzxStartupAnimation"
        anchors.fill: parent
        z: QGroundControl.zOrderTopMost + 1000
        sourceComponent: HQStartupAnimation {
            onFinished: {
                startupAnimationLoader.active = false
                mainWindow.showStartupPrompt()
            }
        }
    }

    /// Saves main window position and size and re-opens it in the same position and size next time
    MainWindowSavedState {
        window: mainWindow
    }

    Settings {
        id: hqStartupSettings
        category: "HQGroundControlStartup"
        property bool disclaimerAccepted: false
    }

    Dialog {
        id: mobileDisplayPresetDialog
        objectName: "mobileDisplayPresetDialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(mainWindow.width * 0.9, ScreenTools.defaultFontPixelWidth * 58)
        height: Math.min(mainWindow.height * 0.86, implicitHeight)
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        title: qsTr("选择手机 / 平板界面")

        onClosed: mainWindow.showStartupPrompt()

        contentItem: QGCFlickable {
            implicitHeight: mobilePresetColumn.implicitHeight
            contentWidth: width
            contentHeight: mobilePresetColumn.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            clip: true

            ColumnLayout {
                id: mobilePresetColumn
                width: parent.width
                spacing: ScreenTools.defaultFontPixelHeight

                QGCLabel {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    text: qsTr("选择适合此设备的初始比例。以后可在应用设置 → 手机 / 平板显示中随时用滑块调整。")
                    wrapMode: Text.WordWrap
                }
                QGCButton {
                    objectName: "mobilePhonePresetButton"
                    Layout.fillWidth: true
                    text: qsTr("手机 · 紧凑 80%")
                    onClicked: {
                        ScreenTools.applyMobileUiPreset(80)
                        mobileDisplayPresetDialog.close()
                    }
                }
                QGCButton {
                    objectName: "mobileTabletPresetButton"
                    Layout.fillWidth: true
                    text: qsTr("平板 · 原始安卓 100%")
                    onClicked: {
                        ScreenTools.applyMobileUiPreset(100)
                        mobileDisplayPresetDialog.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: disclaimerDialog
        anchors.centerIn: parent
        width: Math.min(mainWindow.width * 0.86, ScreenTools.defaultFontPixelWidth * 96)
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        title: qsTr("免责声明（Disclaimer）")
        standardButtons: Dialog.Ok | Dialog.Cancel

        onOpened: {
            standardButton(Dialog.Ok).text = qsTr("我已阅读并接受（Accept）")
            standardButton(Dialog.Cancel).text = qsTr("不接受并退出（Exit）")
        }
        onAccepted: {
            hqStartupSettings.disclaimerAccepted = rememberDisclaimer.checked
            firstRunPromptManager.nextPrompt()
        }
        onRejected: Qt.quit()

        contentItem: ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight
            QGCLabel {
                id: disclaimerText
                Layout.fillWidth: true
                Layout.preferredWidth: disclaimerDialog.width - ScreenTools.defaultFontPixelWidth * 6
                wrapMode: Text.WordWrap
                color: qgcPal.text
                text: qsTr("本软件用于无人机配置、测试与飞行辅助。飞行器、固件、传感器、通信链路和操作环境均可能影响飞行安全。使用者必须遵守当地法律法规、空域规定和设备厂商要求，并在每次飞行前完成必要检查。开发者不对违规操作、错误配置、通信中断或设备故障造成的损失承担责任。\n\nThis software assists UAV configuration, testing and operation. The operator remains responsible for legal compliance, airspace authorization, pre-flight checks and safe operation. The developer is not liable for loss caused by improper configuration, link interruption or equipment failure.")
            }
            QGCCheckBox {
                id: rememberDisclaimer
                checked: true
                palette.windowText: qgcPal.text
                text: qsTr("记住我的选择，以后不再提示（Remember my choice）")
            }
        }

        background: Rectangle {
            color: qgcPal.window
            border.color: qgcPal.groupBorder
            border.width: 1
        }
    }

    QtObject {
        id: firstRunPromptManager

        property var currentDialog:     null
        property var rgPromptIds:       QGroundControl.corePlugin.firstRunPromptsToShow()
        property int nextPromptIdIndex: 0

        function clearNextPromptSignal() {
            if (currentDialog) {
                currentDialog.closed.disconnect(nextPrompt)
            }
        }

        function nextPrompt() {
            if (nextPromptIdIndex < rgPromptIds.length) {
                var component = Qt.createComponent(QGroundControl.corePlugin.firstRunPromptResource(rgPromptIds[nextPromptIdIndex]));
                currentDialog = component.createObject(mainWindow)
                currentDialog.closed.connect(nextPrompt)
                currentDialog.open()
                nextPromptIdIndex++
            } else {
                currentDialog = null
                showPreFlightChecklistIfNeeded()
            }
        }
    }

    readonly property real      _topBottomMargins:          ScreenTools.defaultFontPixelHeight * 0.5

    //-------------------------------------------------------------------------
    //-- Global Scope Variables

    QtObject {
        id: globals

        readonly property var       activeVehicle:                  QGroundControl.multiVehicleManager.activeVehicle
        readonly property real      defaultTextHeight:              ScreenTools.defaultFontPixelHeight
        readonly property real      defaultTextWidth:               ScreenTools.defaultFontPixelWidth
        readonly property var       planMasterControllerFlyView:    flyView.planController
        readonly property var       guidedControllerFlyView:        flyView.guidedController

        // Number of QGCTextField's with validation errors. Used to prevent closing panels with validation errors.
        property int                validationErrorCount:           0

        // Set to a non-empty string to block navigation with a custom reason (e.g. during calibration)
        property string             navigationBlockedReason:        ""

        // Property to manage RemoteID quick access to settings page
        property bool               commingFromRIDIndicator:        false
    }

    /// Default color palette used throughout the UI
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    //-------------------------------------------------------------------------
    //-- Actions

    signal armVehicleRequest
    signal forceArmVehicleRequest
    signal disarmVehicleRequest
    signal vtolTransitionToFwdFlightRequest
    signal vtolTransitionToMRFlightRequest
    signal showPreFlightChecklistIfNeeded

    //-------------------------------------------------------------------------
    //-- Global Scope Functions

    // This function is used to prevent view switching if there are validation errors
    function allowViewSwitch(previousValidationErrorCount = 0, showErrorOnDisallow = true) {
        // Check for explicit navigation block (e.g. calibration in progress)
        if (globals.navigationBlockedReason !== "") {
            if (showErrorOnDisallow) {
                validationErrorToast.text = globals.navigationBlockedReason
                if (validationErrorToast.visible) {
                    validationErrorToast.close()
                }
                validationErrorToast.open()
            }
            return false
        }
        // Run validation on active focus control to ensure it is valid before switching views
        if (mainWindow.activeFocusControl instanceof FactTextField) {
            mainWindow.activeFocusControl._onEditingFinished()
        }
        var allowed = globals.validationErrorCount <= previousValidationErrorCount
        if (!allowed && showErrorOnDisallow) {
            validationErrorToast.text = qsTr("Please correct the invalid value before continuing")
            if (validationErrorToast.visible) {
                validationErrorToast.close()
            }
            validationErrorToast.open()
        }
        return allowed
    }

    function setWorkspaceVisibility(view, visible) {
        // Keep the outgoing map visible until the transition ends, without toggling
        // PlanView's visibility-driven camera synchronization a second time.
        if (!visible && hdzxNavigationCommit && hdzxNavigationAnimationsEnabled
                && view === hdzxOutgoingWorkspace) return
        view.visible = visible
    }

    function showPlanView() {
        if (!hdzxNavigationCommit) workspaceSlide.settle()
        hdzxWorkspace = "plan"
        setWorkspaceVisibility(flyView, false)
        setWorkspaceVisibility(planView, true)
        setWorkspaceVisibility(geoView, false)
        setWorkspaceVisibility(toolDrawer, false)
    }

    function showFlyView() {
        if (!hdzxNavigationCommit) workspaceSlide.settle()
        hdzxWorkspace = "flight"
        setWorkspaceVisibility(flyView, true)
        setWorkspaceVisibility(planView, false)
        setWorkspaceVisibility(geoView, false)
        setWorkspaceVisibility(toolDrawer, false)
    }

    function showGeoView() {
        if (!hdzxNavigationCommit) workspaceSlide.settle()
        hdzxWorkspace = "geo"
        setWorkspaceVisibility(flyView, false)
        setWorkspaceVisibility(planView, false)
        setWorkspaceVisibility(geoView, true)
        setWorkspaceVisibility(toolDrawer, false)
    }

    function showTool(toolTitle, toolSource, toolIcon) {
        if (!hdzxNavigationCommit) workspaceSlide.settle()
        hdzxWorkspace = String(toolSource).indexOf("HQAITuningSetup") >= 0 ? "ai"
                     : String(toolSource).indexOf("VehicleConfig") >= 0 ? "setup"
                     : String(toolSource).indexOf("AnalyzeView") >= 0 ? "analyze" : "settings"
        toolDrawer.backIcon     = flyView.visible ? "/qmlimages/PaperPlane.svg" : (geoView.visible ? "/InstrumentValueIcons/globe.svg" : "/qmlimages/Plan.svg")
        setWorkspaceVisibility(flyView, false)
        setWorkspaceVisibility(planView, false)
        setWorkspaceVisibility(geoView, false)
        toolDrawer.toolTitle    = toolTitle
        toolDrawer.toolSource   = toolSource
        loadToolSource(toolSource)
        toolDrawer.toolIcon     = toolIcon
        toolDrawer.visible      = true
    }

    function visibleWorkspaceItem() {
        return toolDrawer.visible ? toolDrawer
             : planView.visible ? planView : geoView.visible ? geoView : flyView
    }

    function releaseInactiveTool() {
        if (!toolLoaderA || !toolLoaderB) return
        // Retain at most two pages. Returning to analysis/settings reuses its model.
        toolLoaderA.visible = toolDrawer.visible && hdzxToolSlot === 0
        toolLoaderB.visible = toolDrawer.visible && hdzxToolSlot === 1
    }

    function loadToolSource(source) {
        const previous = toolDrawerLoader
        if (String(toolLoaderA.source) === String(source)) hdzxToolSlot = 0
        else if (String(toolLoaderB.source) === String(source)) hdzxToolSlot = 1
        else if (String(previous.source) !== String(source) && String(previous.source) !== "")
            hdzxToolSlot = 1 - hdzxToolSlot
        const next = toolDrawerLoader
        if (previous !== next) previous.visible = false
        next.visible = true
        next.source = source
        if (hdzxWorkspace !== "settings") _pendingSettingsPage = ""
        if (hdzxWorkspace !== "setup") {
            _pendingVehiclePage = ""
            _pendingPageVehicle = null
        }
        toolPageLoaded(next)
    }

    function toolPageLoaded(loader) {
        if (loader !== toolDrawerLoader || loader.status !== Loader.Ready || !loader.item) return
        if (_pendingSettingsPage !== "" && loader.item.showSettingsPage) {
            loader.item.showSettingsPage(_pendingSettingsPage)
            _pendingSettingsPage = ""
        }
        if (_pendingVehiclePage !== "" && hdzxWorkspace === "setup") {
            const action = _pendingVehiclePage
            _pendingVehiclePage = ""
            if (_pendingPageVehicle === globals.activeVehicle) {
                if (action === "parameters") loader.item.showParametersPanel()
                else if (globals.activeVehicle) {
                    const component = globals.activeVehicle.autopilotPlugin.findKnownVehicleComponent(_pendingVehicleComponent)
                    if (component) loader.item.showVehicleComponentPanel(component)
                }
            }
            _pendingPageVehicle = null
        }
    }

    function navigateWorkspace(destination, swipe = false) {
        if (!allowViewSwitch()) return
        if (destination === "tools") {
            showToolSelectDialog()
            return
        }
        if (destination === hdzxWorkspace) return
        const order = ["flight", "plan", "setup", "analyze", "settings", "ai"]
        if (order.indexOf(destination) < 0) return
        const forward = order.indexOf(destination) > order.indexOf(hdzxWorkspace)
        workspaceSlide.settle()
        const previous = visibleWorkspaceItem()
        hdzxOutgoingWorkspace = previous
        const previousTool = toolDrawerLoader
        closeIndicatorDrawer()
        hdzxNavigationCommit = true
        try {
            if (destination === "flight") showFlyView()
            else if (destination === "plan") showPlanView()
            else if (destination === "setup") showVehicleConfig()
            else if (destination === "ai") showAITuningTool()
            else if (destination === "analyze") showAnalyzeTool()
            else if (destination === "settings") showSettingsTool()
        } finally {
            hdzxNavigationCommit = false
        }
        const next = destination === "flight" ? flyView : destination === "plan" ? planView : toolDrawer
        if (previous === toolDrawer && next === toolDrawer)
            workspaceSlide.slide(previousTool, toolDrawerLoader, forward, false)
        else workspaceSlide.slide(previous, next, forward, false)
        hdzxOutgoingWorkspace = null
        if (!workspaceSlide.running) releaseInactiveTool()
    }

    function showAITuningTool() {
        showTool(qsTr("AI Tuning"), "qrc:/qml/QGroundControl/VehicleSetup/HQAITuningSetup.qml", "/hdzx/ai.svg")
    }





    function showAnalyzeTool() {
        showTool(qsTr("Analyze Tools"), "qrc:/qml/QGroundControl/AnalyzeView/AnalyzeView.qml", "/qmlimages/Analyze.svg")
    }

    function showManualConnection() {
        manualConnectionDialogFactory.open()
    }

    QGCPopupDialogFactory {
        id: manualConnectionDialogFactory
        dialogComponent: manualConnectionDialogComponent
    }

    Component {
        id: manualConnectionDialogComponent

        QGCPopupDialog {
            id: manualDialog
            objectName: "hdzxManualConnectionDialog"
            title: qsTr("手动连接（Manual Connect）")
            buttons: Dialog.Ok | Dialog.Cancel
            acceptButtonEnabled: editingConfig !== null && linkSettingsLoader.status === Loader.Ready

            property var editingConfig: null
            readonly property var manualLinkTypes: ScreenTools.isSerialAvailable
                                                    ? [LinkConfiguration.TypeSerial, LinkConfiguration.TypeUdp, LinkConfiguration.TypeTcp]
                                                    : [LinkConfiguration.TypeUdp, LinkConfiguration.TypeTcp]
            readonly property var manualLinkTypeNames: ScreenTools.isSerialAvailable
                                                        ? [qsTr("串口（Serial）"), qsTr("UDP"), qsTr("TCP")]
                                                        : [qsTr("UDP"), qsTr("TCP")]

            Component.onCompleted: {
                replaceEditingConfig(manualLinkTypes[0])
                linkTypeCombo.currentIndex = 0
            }

            function replaceEditingConfig(linkType) {
                if (editingConfig) {
                    const oldConfig = editingConfig
                    editingConfig = null
                    QGroundControl.linkManager.cancelConfigurationEditing(oldConfig)
                }
                editingConfig = QGroundControl.linkManager.createConfiguration(linkType, qsTr("临时手动连接"))
            }

            onAccepted: {
                if (linkSettingsLoader.item && linkSettingsLoader.item.saveSettings) {
                    linkSettingsLoader.item.saveSettings()
                }
                editingConfig.name = qsTr("手动连接（%1）").arg(linkTypeCombo.currentText)
                editingConfig.dynamic = true
                QGroundControl.linkManager.endCreateConfiguration(editingConfig)
                mainWindow.connectLinkWithStatus(editingConfig)
                editingConfig = null
            }
            onRejected: {
                if (editingConfig) {
                    QGroundControl.linkManager.cancelConfigurationEditing(editingConfig)
                    editingConfig = null
                }
            }

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelHeight * 0.7

                QGCLabel {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: qsTr("选择连接类型并填写参数后直接建立临时 MAVLink 连接；不会开启自动连接或修改飞控参数。")
                }

                RowLayout {
                    Layout.fillWidth: true

                    QGCLabel { text: qsTr("连接类型（Type）") }
                    QGCComboBox {
                        id: linkTypeCombo
                        Layout.fillWidth: true
                        model: manualDialog.manualLinkTypeNames
                        onActivated: function(index) {
                            const requestedType = manualDialog.manualLinkTypes[index]
                            if (manualDialog.editingConfig && requestedType !== manualDialog.editingConfig.linkType) {
                                manualDialog.replaceEditingConfig(requestedType)
                            }
                        }
                    }
                }

                Loader {
                    id: linkSettingsLoader
                    Layout.fillWidth: true
                    Layout.preferredHeight: item ? item.implicitHeight : 0
                    source: subEditConfig && subEditConfig.settingsURL
                            ? "qrc:/qml/QGroundControl/AppSettings/" + subEditConfig.settingsURL : ""

                    property var subEditConfig: manualDialog.editingConfig
                    property int _firstColumnWidth: ScreenTools.defaultFontPixelWidth * 12
                    property int _secondColumnWidth: ScreenTools.defaultFontPixelWidth * 30
                    property int _rowSpacing: ScreenTools.defaultFontPixelHeight / 2
                    property int _colSpacing: ScreenTools.defaultFontPixelWidth / 2

                    onStatusChanged: {
                        if (status === Loader.Error) {
                            console.warn("Failed to load manual link settings page:", source)
                        }
                    }
                }
            }
        }
    }

    function showVehicleConfig() {
        showTool(qsTr("Vehicle Configuration"), "qrc:/qml/QGroundControl/VehicleSetup/VehicleConfigView.qml", "/res/HQLogo.png")
    }

    function showVehicleConfigParametersPage() {
        showVehicleConfig()
        _pendingVehiclePage = "parameters"
        _pendingPageVehicle = globals.activeVehicle
        toolPageLoaded(toolDrawerLoader)
    }

    function showKnownVehicleComponentConfigPage(knownVehicleComponent) {
        if (!globals.activeVehicle) return
        showVehicleConfig()
        _pendingVehiclePage = "component"
        _pendingVehicleComponent = knownVehicleComponent
        _pendingPageVehicle = globals.activeVehicle
        toolPageLoaded(toolDrawerLoader)
    }

    function showSettingsTool(settingsPage = "") {
        _pendingSettingsPage = settingsPage
        showTool(qsTr("应用设置"), "qrc:/qml/QGroundControl/Controls/AppSettings.qml", "/res/HQLogo.png")
    }

    function showFlyVehicleConfig(kind, knownComponent = -1) {
        if (!QGroundControl.multiVehicleManager.activeVehicle) {
            QGroundControl.showMessageDialog(mainWindow, qsTr("尚未连接飞机"),
                qsTr("请先连接飞机并等待参数下载完成，再打开飞行器配置侧栏。"), Dialog.Ok)
            return
        }
        showFlyView()
        flyView.showVehicleConfigSidebar(kind, knownComponent)
    }

    //-------------------------------------------------------------------------
    //-- Global simple message dialog

    function _showMessageDialogWorker(owner, dialogTitle, dialogText, buttons = Dialog.Ok, acceptFunction = null, closeFunction = null, bypassNavigationCheck = false) {
        let dialog = simpleMessageDialogComponent.createObject(owner, { title: dialogTitle, text: dialogText, buttons: buttons, acceptFunction: acceptFunction, closeFunction: closeFunction, bypassNavigationCheck: bypassNavigationCheck })
        dialog.open()
    }

    // This variant is only meant to be called by QGCApplication
    function _showMessageDialog(dialogTitle, dialogText) {
        _showMessageDialogWorker(mainWindow, dialogTitle, dialogText)
    }

    // This variant is only meant to be called by QGCApplication. Ok reboots the active vehicle.
    function _showRebootVehicleDialog(dialogTitle, dialogText) {
        _showMessageDialogWorker(mainWindow, dialogTitle,
                                 dialogText + " " + qsTr("Click Ok to reboot the vehicle now."),
                                 Dialog.Ok | Dialog.Cancel,
                                 function() {
                                     const activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
                                     if (activeVehicle) {
                                         activeVehicle.rebootVehicle()
                                     }
                                 })
    }

    Connections {
        target: QGroundControl

        function onShowMessageDialogRequested(owner, title, text, buttons, acceptFunction, closeFunction) {
            _showMessageDialogWorker(owner, title, text, buttons, acceptFunction, closeFunction)
        }
    }

    Component {
        id: simpleMessageDialogComponent

        QGCSimpleMessageDialog {
        }
    }

    property bool _forceClose: false
    property bool suppressCriticalVehicleMessages: false

    function finishCloseProcess() {
        _forceClose = true
        // For some reason on the Qml side Qt doesn't automatically disconnect a signal when an object is destroyed.
        // So we have to do it ourselves otherwise the signal flows through on app shutdown to an object which no longer exists.
        firstRunPromptManager.clearNextPromptSignal()
        QGroundControl.linkManager.shutdown()
        QGroundControl.videoManager.stopVideo();
        mainWindow.close()
    }

    // Check for things which should prevent the app from closing
    //  Returns true if it is OK to close
    readonly property int _skipUnsavedMissionCheckMask: 0x01
    readonly property int _skipPendingParameterWritesCheckMask: 0x02
    readonly property int _skipActiveConnectionsCheckMask: 0x04
    property int _closeChecksToSkip: 0
    property bool _reentrantCloseGuard: false
    function performCloseChecks() {
        if (!(_closeChecksToSkip & _skipUnsavedMissionCheckMask) && !checkForUnsavedMission()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipPendingParameterWritesCheckMask) && !checkForPendingParameterWrites()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipActiveConnectionsCheckMask) && !checkForActiveConnections()) {
            return false
        }
        finishCloseProcess()
        return true
    }

    function checkForUnsavedMission() {
        // Only warn when edits are neither saved to disk nor uploaded to the vehicle.
        // If either happened the edits are recoverable, so closing loses nothing.
        // With no active vehicle an upload can't have happened, so treat the plan as
        // not uploaded regardless of dirtyForUpload.
        if (planView._planMasterController.dirtyForSave &&
                (planView._planMasterController.dirtyForUpload || !QGroundControl.multiVehicleManager.activeVehicle)) {
            let accepted = false
            _reentrantCloseGuard = true
            _showMessageDialogWorker(mainWindow, qsTr("Unsaved Mission"),
                              qsTr("You have a mission edit in progress which has not been saved/uploaded. If you close you will lose changes. Are you sure you want to close?"),
                              Dialog.Yes | Dialog.No,
                              function() { accepted = true; _closeChecksToSkip |= _skipUnsavedMissionCheckMask; performCloseChecks() },
                              function() { if (!accepted) _reentrantCloseGuard = false },
                              true /* bypassNavigationCheck */)
            return false
        } else {
            return true
        }
    }

    function checkForPendingParameterWrites() {
        for (var index=0; index<QGroundControl.multiVehicleManager.vehicles.count; index++) {
            if (QGroundControl.multiVehicleManager.vehicles.get(index).parameterManager.pendingWrites) {
                let accepted = false
                _reentrantCloseGuard = true
                _showMessageDialogWorker(mainWindow, qsTr("Pending Parameter Updates"),
                    qsTr("You have pending parameter updates to a vehicle. If you close you will lose changes. Are you sure you want to close?"),
                    Dialog.Yes | Dialog.No,
                    function() { accepted = true; _closeChecksToSkip |= _skipPendingParameterWritesCheckMask; performCloseChecks() },
                    function() { if (!accepted) _reentrantCloseGuard = false },
                    true /* bypassNavigationCheck */)
                return false
            }
        }
        return true
    }

    function checkForActiveConnections() {
        if (QGroundControl.multiVehicleManager.activeVehicle) {
            let accepted = false
            _reentrantCloseGuard = true
            _showMessageDialogWorker(mainWindow, qsTr("Active Vehicle Connections"),
                qsTr("There are still active connections to vehicles. Are you sure you want to exit?"),
                Dialog.Yes | Dialog.No,
                function() { accepted = true; _closeChecksToSkip |= _skipActiveConnectionsCheckMask; performCloseChecks() },
                function() { if (!accepted) _reentrantCloseGuard = false },
                true /* bypassNavigationCheck */)
            return false
        } else {
            return true
        }
    }

    onClosing: (close) => {
        if (!_forceClose) {
            if (_reentrantCloseGuard) {
                close.accepted = false
                return
            }
            _closeChecksToSkip = 0
            close.accepted = performCloseChecks()
        }
    }

    background: Rectangle {
        anchors.fill:   parent
        color:          QGroundControl.globalPalette.window
    }

    Item {
        id: workspaceViewport
        anchors.leftMargin: mainWindow.hdzxRailWidth
        objectName: "hdzxWorkspaceViewport"
        anchors.fill: parent
        clip: true
        onWidthChanged: if (workspaceSlide) workspaceSlide.settle()
        onHeightChanged: if (workspaceSlide) workspaceSlide.settle()
    }

    FlyView {
        id:                     flyView
        parent: workspaceViewport
        z: 0
        transform: Translate { x: workspaceSlide.offsetFor(flyView) }
        opacity: workspaceSlide.opacityFor(flyView)
        enabled: mainWindow.hdzxWorkspace === "flight"
        objectName:             "mainView_fly"
        anchors.fill:           parent
    }

    PlanView {
        id:             planView
        parent: workspaceViewport
        z: 1
        transform: Translate { x: workspaceSlide.offsetFor(planView) }
        opacity: workspaceSlide.opacityFor(planView)
        enabled: mainWindow.hdzxWorkspace === "plan"
        objectName:     "mainView_plan"
        anchors.fill:   parent
        visible:        false
    }

    FlyViewGeo {
        id:             geoView
        parent: workspaceViewport
        z: 2
        transform: Translate { x: workspaceSlide.offsetFor(geoView) }
        opacity: workspaceSlide.opacityFor(geoView)
        enabled: mainWindow.hdzxWorkspace === "geo"
        objectName:     "mainView_geo"
        anchors.fill:   parent
        visible:        false
    }



    footer: LogReplayStatusBar {
        visible: QGroundControl.settingsManager.flyViewSettings.showLogReplayStatusBar.rawValue
    }

    MessageDialog {
        id:                 showTouchAreasNotification
        title:              qsTr("Debug Touch Areas")
        text:               qsTr("Touch Area display toggled")
        buttons:            MessageDialog.Ok
    }

    MessageDialog {
        id:                 advancedModeOnConfirmation
        title:              qsTr("Advanced Mode")
        text:               QGroundControl.corePlugin.showAdvancedUIMessage
        buttons:            MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = true
            }
        }
    }

    MessageDialog {
        id:                 advancedModeOffConfirmation
        title:              qsTr("Advanced Mode")
        text:               qsTr("Turn off Advanced Mode?")
        buttons:            MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = false
            }
        }
    }

    function showToolSelectDialog() {
        if (mainWindow.allowViewSwitch()) {
            mainWindow.showIndicatorDrawer(toolSelectComponent, null)
        }
    }

    // Toast notification shown when a view switch is blocked by a validation error
    ToolTip {
        id:             validationErrorToast
        x:              (mainWindow.width - width) / 2
        y:              mainWindow.height - height - ScreenTools.defaultFontPixelHeight * 3
        timeout:        3000
        closePolicy:    Popup.NoAutoClose
        text:           qsTr("Please correct the invalid value before continuing")

        background: Rectangle {
            color:  qgcPal.alertBackground
            radius: ScreenTools.defaultFontPixelWidth / 2
        }

        contentItem: QGCLabel {
            text:   validationErrorToast.text
            color:  qgcPal.alertText
        }
    }

    Component {
        id: toolSelectComponent

        SelectViewDropdown {
        }
    }

    Rectangle {
        id:             toolDrawer
        parent: workspaceViewport
        z: 10
        transform: Translate { x: workspaceSlide.offsetFor(toolDrawer) }
        opacity: workspaceSlide.opacityFor(toolDrawer)
        enabled: ["setup", "analyze", "settings", "ai"].indexOf(mainWindow.hdzxWorkspace) >= 0
        objectName:     "mainView_toolDrawer"
        anchors.fill:   parent
        visible:        false
        color:          qgcPal.window

        property var backIcon
        property string toolTitle
        property url toolSource: ""
        property var toolIcon
        property bool showVehicleStatusBar: true

        onVisibleChanged: if (!visible && !mainWindow.hdzxNavigationCommit) mainWindow.releaseInactiveTool()

        // This need to block click event leakage to underlying map.
        DeadMouseArea {
            anchors.fill: parent
        }

        Item {
            id: drawerGuidedSliderProxy
            visible: false
        }

        FlyViewToolBar {
            id: persistentVehicleToolbar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            guidedValueSlider: drawerGuidedSliderProxy
            visible: (!!QGroundControl.multiVehicleManager.activeVehicle || connectionAttempt.waiting || connectionAttempt.failed)
                     && toolDrawer.showVehicleStatusBar
        }

        Rectangle {
            id:             toolDrawerToolbar
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    persistentVehicleToolbar.visible ? persistentVehicleToolbar.bottom : parent.top
            height:         ScreenTools.toolbarHeight
            color:          qgcPal.toolbarBackground

            RowLayout {
                id:                 toolDrawerToolbarLayout
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.left:       parent.left
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                spacing:            ScreenTools.defaultFontPixelWidth

                QGCToolBarButton {
                    id: qgcButton
                    objectName: "toolbar_qgcLogo"
                    height: parent.height
                    icon.source: "/res/HQLogo.png"
                    logo: true
                    visible: false
                    onClicked: mainWindow.showToolSelectDialog()
                }

                QGCLabel {
                    id:             toolbarDrawerText
                    text:           toolDrawer.toolTitle
                    font.pointSize: ScreenTools.largeFontPointSize
                    font.weight: Font.DemiBold
                }
            }

            QGCButton {
                anchors.right: parent.right
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth
                anchors.verticalCenter: parent.verticalCenter
                text: toolDrawer.showVehicleStatusBar ? qsTr("隐藏飞行状态") : qsTr("显示飞行状态")
                visible: !!QGroundControl.multiVehicleManager.activeVehicle
                onClicked: toolDrawer.showVehicleStatusBar = !toolDrawer.showVehicleStatusBar
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: toolDrawerToolbar.bottom
            anchors.bottom: parent.bottom
            clip: true
            Loader {
                id: toolLoaderA
                objectName: "hdzxToolLoaderA"
                anchors.fill: parent
                z: mainWindow.hdzxToolSlot === 0 ? 1 : 0
                enabled: mainWindow.hdzxToolSlot === 0
                opacity: workspaceSlide.opacityFor(toolLoaderA)
                transform: Translate { x: workspaceSlide.offsetFor(toolLoaderA) }
                onLoaded: mainWindow.toolPageLoaded(toolLoaderA)
            }
            Loader {
                id: toolLoaderB
                objectName: "hdzxToolLoaderB"
                anchors.fill: parent
                z: mainWindow.hdzxToolSlot === 1 ? 1 : 0
                enabled: mainWindow.hdzxToolSlot === 1
                opacity: workspaceSlide.opacityFor(toolLoaderB)
                visible: false
                transform: Translate { x: workspaceSlide.offsetFor(toolLoaderB) }
                onLoaded: mainWindow.toolPageLoaded(toolLoaderB)
            }
            ColumnLayout {
                anchors.centerIn: parent
                visible: toolDrawerLoader.status === Loader.Loading || toolDrawerLoader.status === Loader.Error
                z: 2
                BusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    running: toolDrawerLoader.status === Loader.Loading && toolDrawer.visible
                    visible: running
                }
                QGCLabel { text: toolDrawerLoader.status === Loader.Error ? qsTr("页面加载失败") : qsTr("正在加载…") }
                QGCButton {
                    Layout.alignment: Qt.AlignHCenter
                    visible: toolDrawerLoader.status === Loader.Error
                    text: qsTr("重试")
                    onClicked: { toolDrawerLoader.source = ""; mainWindow.loadToolSource(toolDrawer.toolSource) }
                }
            }
        }

        // HQ identity watermark for settings, analysis and configuration pages.
        // It is intentionally non-interactive and placed in otherwise empty space.
        RowLayout {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 3
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 2
            spacing: ScreenTools.defaultFontPixelWidth
            opacity: 0.19
            enabled: false
            z: 20

            Image {
                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 4.6
                Layout.preferredHeight: Layout.preferredWidth
                source: "/res/HQLogo.png"
                sourceSize: Qt.size(256, 256)
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }

            ColumnLayout {
                spacing: 0
                QGCLabel {
                    text: "HDZX  FLIGHT WORKSPACE"
                    color: "#68C9FF"
                    font.family: ScreenTools.hqUiFontFamily
                    font.weight: Font.DemiBold
                    font.pointSize: ScreenTools.mediumFontPointSize
                    font.letterSpacing: 1.5
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#FF7A18" }
                        GradientStop { position: 0.72; color: "#278ED5" }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
                QGCLabel {
                    text: "段中旭工作室"
                    color: "#9BC7EF"
                    font.family: ScreenTools.hqUiFontFamily
                    font.weight: Font.DemiBold
                    font.pointSize: ScreenTools.mediumFontPointSize * 1.15
                    font.letterSpacing: 1
                }
            }
        }
    }

    HDZXNavigationRail {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: mainWindow.hdzxRailWidth
        section: mainWindow.hdzxWorkspace
        mobileGestures: ScreenTools.isMobile
        onNavigateRequested: function(destination) { mainWindow.navigateWorkspace(destination) }
        onSwipeNavigateRequested: function(destination) { mainWindow.navigateWorkspace(destination, true) }
        onManualConnectionRequested: mainWindow.showManualConnection()
    }

    property bool hdzxNavigationCommit: false
    property Item hdzxOutgoingWorkspace: null
    readonly property Item hdzxArrivalTarget: toolDrawerLoader
    readonly property bool hdzxSlideRunning: workspaceSlide.running
    readonly property real hdzxSlideOffset: workspaceSlide.incomingOffset
    HDZXWorkspaceSlide {
        id: workspaceSlide
        animationsEnabled: mainWindow.hdzxNavigationAnimationsEnabled
        motionMode: mainWindow.hdzxNavigationMotionMode
        onSettled: mainWindow.releaseInactiveTool()
    }
    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged() { workspaceSlide.settle() }
    }

    Connections {
        target: toolDrawerLoader ? toolDrawerLoader.item : null
        ignoreUnknownSignals: true
        function onConfigurationRequested() { Qt.callLater(mainWindow.showVehicleConfig) }
    }

    //-------------------------------------------------------------------------
    //-- Critical Vehicle Message Popup

    function showCriticalVehicleMessage(message) {
        if (suppressCriticalVehicleMessages) {
            return
        }
        if (criticalVehicleMessagePopup.visible || QGroundControl.videoManager.fullScreen) {
            // We received additional warning message while an older warning message was still displayed.
            // When the user close the older one drop the message indicator tool so they can see the rest of them.
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = true
        } else {
            criticalVehicleMessagePopup.criticalVehicleMessage      = message
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false
            criticalVehicleMessagePopup.open()
        }
    }

    Popup {
        id:                 criticalVehicleMessagePopup
        y:                  ScreenTools.toolbarHeight + ScreenTools.defaultFontPixelHeight
        x:                  Math.round((mainWindow.width - width) * 0.5)
        width:              mainWindow.width  * 0.55
        height:             criticalVehicleMessageText.contentHeight + ScreenTools.defaultFontPixelHeight * 2
        modal:              false
        focus:              true

        property alias  criticalVehicleMessage:             criticalVehicleMessageText.text
        property bool   additionalCriticalMessagesReceived: false

        background: Rectangle {
            anchors.fill:   parent
            color:          qgcPal.alertBackground
            radius:         ScreenTools.defaultFontPixelHeight * 0.5
            border.color:   qgcPal.alertBorder
            border.width:   2

            Rectangle {
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.top:                parent.top
                anchors.topMargin:          -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      vehicleWarningLabel.contentWidth + _margins
                height:                     vehicleWarningLabel.contentHeight + _margins

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 vehicleWarningLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Vehicle Error")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }

            Rectangle {
                id:                         additionalErrorsIndicator
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.bottom:             parent.bottom
                anchors.bottomMargin:       -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      additionalErrorsLabel.contentWidth + _margins
                height:                     additionalErrorsLabel.contentHeight + _margins
                visible:                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 additionalErrorsLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Additional errors received")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }
        }

        QGCLabel {
            id:                 criticalVehicleMessageText
            width:              criticalVehicleMessagePopup.width - ScreenTools.defaultFontPixelHeight
            anchors.centerIn:   parent
            wrapMode:           Text.WordWrap
            color:              qgcPal.alertText
            textFormat:         TextEdit.RichText
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                criticalVehicleMessagePopup.close()
                if (criticalVehicleMessagePopup.additionalCriticalMessagesReceived) {
                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false;
                    flyView.dropMainStatusIndicatorTool();
                } else if (QGroundControl.multiVehicleManager.activeVehicle) {
                    QGroundControl.multiVehicleManager.activeVehicle.resetErrorLevelMessages();
                }
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- Indicator Drawer

    function showIndicatorDrawer(drawerComponent, indicatorItem) {
        indicatorDrawer.sourceComponent = drawerComponent
        indicatorDrawer.indicatorItem = indicatorItem
        indicatorDrawer.open()
    }

    function closeIndicatorDrawer() {
        indicatorDrawer.close()
    }

    Popup {
        id:             indicatorDrawer
        x:              calcXPosition()
        y:              ScreenTools.toolbarHeight + _margins
        leftInset:      0
        rightInset:     0
        topInset:       0
        bottomInset:    0
        padding:        _margins * 2
        visible:        false
        modal:          true
        focus:          true
        closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var sourceComponent
        property var indicatorItem

        property bool _expanded:    false
        property real _margins:     ScreenTools.defaultFontPixelHeight / 4

        function calcXPosition() {
            if (indicatorItem) {
                var xCenter = indicatorItem.mapToItem(mainWindow.contentItem, indicatorItem.width / 2, 0).x
                return Math.max(_margins, Math.min(xCenter - (contentItem.implicitWidth / 2), mainWindow.contentItem.width - contentItem.implicitWidth - _margins - (indicatorDrawer.padding * 2) - (ScreenTools.defaultFontPixelHeight / 2)))
            } else {
                return _margins
            }
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 240; easing.type: Easing.OutQuint }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 130; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; to: 0.98; duration: 130; easing.type: Easing.OutCubic }
            }
        }
        onAboutToShow: {
            _expanded                               = false;
            indicatorDrawerLoader.sourceComponent   = indicatorDrawer.sourceComponent
        }
        onClosed: {
            _expanded                               = false
            indicatorItem                           = undefined
            indicatorDrawerLoader.sourceComponent   = undefined
        }

        background: Item {
            Rectangle {
                id:             backgroundRect
                anchors.fill:   parent
                color:          QGroundControl.globalPalette.window
                radius:         indicatorDrawer._margins
                opacity:        0.85
            }

            Rectangle {
                objectName:                 "indicatorDrawerExpandButton"
                anchors.horizontalCenter:   backgroundRect.right
                anchors.verticalCenter:     backgroundRect.top
                width:                      ScreenTools.largeFontPixelHeight
                height:                     width
                radius:                     width / 2
                color:                      QGroundControl.globalPalette.button
                border.color:               QGroundControl.globalPalette.buttonText
                visible:                    indicatorDrawerLoader.item && indicatorDrawerLoader.item._showExpand && !indicatorDrawer._expanded

                QGCLabel {
                    anchors.centerIn:   parent
                    text:               ">"
                    color:              QGroundControl.globalPalette.buttonText
                }

                QGCMouseArea {
                    fillItem: parent
                    onClicked: indicatorDrawer._expanded = true
                }
            }
        }

        contentItem: QGCFlickable {
            id:             indicatorDrawerLoaderFlickable
            implicitWidth:  Math.min(mainWindow.contentItem.width - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.width)
            implicitHeight: Math.min(mainWindow.contentItem.height - ScreenTools.toolbarHeight - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.height)
            contentWidth:   indicatorDrawerLoader.width
            contentHeight:  indicatorDrawerLoader.height

            Loader {
                id:         indicatorDrawerLoader
                objectName: "indicatorDrawerLoader"

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "expanded"
                    value:      indicatorDrawer._expanded
                }

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "drawer"
                    value:      indicatorDrawer
                }
            }
        }
    }

    // Analyze page items (both in-panel and popped-out windows) are created with mainWindow as their
    // QObject parent so their lifetime is not tied to AnalyzeView. This lets a popped-out window
    // survive AnalyzeView being unloaded from the tool drawer.

    // Tracks the analyze page item currently shown inside AnalyzeView's panel (not popped out).
    // null when no page is loaded or the item has been handed off to a popup window.
    property var _inPanelAnalyzePage: null

    // Called by AnalyzeView.Component.onDestruction to destroy the in-panel item while
    // panelContainer is still alive.
    function destroyInPanelAnalyzePage() {
        if (_inPanelAnalyzePage) {
            _inPanelAnalyzePage.destroy()
            _inPanelAnalyzePage = null
        }
    }

    // Called by AnalyzeView to create an analyze page item owned by mainWindow.
    // The caller sets the visual parent to panelContainer after creation.
    function createAnalyzePage(source) {
        if (_inPanelAnalyzePage) {
            _inPanelAnalyzePage.destroy()
            _inPanelAnalyzePage = null
        }
        var component = Qt.createComponent(source)
        if (component.status !== Component.Ready) {
            console.warn("createAnalyzePage failed source:", source, "errorString:", component.errorString())
            return null
        }
        _inPanelAnalyzePage = component.createObject(mainWindow)
        return _inPanelAnalyzePage
    }

    // Called by AnalyzeView when the in-panel item is handed off to a popup window.
    // Clears _inPanelAnalyzePage so destroyInPanelAnalyzePage() does not destroy it
    // when AnalyzeView is torn down.
    function analyzePageMovedToPopup() {
        _inPanelAnalyzePage = null
    }

    function createWindowedAnalyzePage(title, source, requiresVehicle, existingItem) {
        var windowedPage = windowedAnalyzePage.createObject(mainWindow)
        windowedPage.title = title
        windowedPage.requiresVehicle = requiresVehicle
        if (existingItem) {
            windowedPage.adoptItem(existingItem)
        } else {
            windowedPage.source = source
        }
        windowedPage.visible = true
    }

    Component {
        id: windowedAnalyzePage

        Window {
            width:      ScreenTools.defaultFontPixelWidth  * 100
            height:     ScreenTools.defaultFontPixelHeight * 40
            visible:    false

            property alias source: loader.source
            property bool requiresVehicle: false

            function adoptItem(item) {
                loader.visible = false
                loader.source = ""
                item.parent = contentRect
                item.anchors.fill = contentRect
                item.popped = true
                item.visible = true
            }

            Connections {
                target: QGroundControl.multiVehicleManager
                function onActiveVehicleChanged() {
                    if (requiresVehicle) {
                        close()
                    }
                }
            }

            Rectangle {
                id:             contentRect
                color:          QGroundControl.globalPalette.window
                anchors.fill:   parent

                Loader {
                    id:             loader
                    anchors.fill:   parent
                    onLoaded:       item.popped = true
                }
            }

            onClosing: {
                visible = false
                // Destroy any reparented children (not owned by loader)
                for (var i = contentRect.children.length - 1; i >= 0; i--) {
                    var child = contentRect.children[i]
                    if (child !== loader) {
                        child.destroy()
                    }
                }
                source = ""
                Qt.callLater(destroy)
            }
        }
    }
}
