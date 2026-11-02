import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
import QGroundControl.LogViewer

AnalyzePage {
    id: logViewerPage
    pageComponent: pageComponent
    pageDescription: qsTr("Open and inspect DataFlash (.bin), PX4 ULog (.ulg), and telemetry (.tlog) logs in a unified workflow.")
    allowPopout: true
    // A usable fields panel and chart need a minimum working area. The base
    // AnalyzePage provides touch scrolling below this size rather than clipping.
    minimumContentWidth: ScreenTools.defaultFontPixelWidth * 76

    Component {
        id: pageComponent

        ColumnLayout {
            objectName: "logViewerContent"
            width: availableWidth
            height: Math.max(availableHeight, implicitHeight)
            spacing: ScreenTools.defaultFontPixelHeight

            property string pendingBinFile: ""
            property bool assessAfterLoad: false

            QGCPopupDialogFactory {
                id: assessmentFactory
                dialogComponent: Component {
                    LogAssessmentDialog {
                        logParser: fileParser
                        onShowFieldsRequested: (fields, time) => {
                            // Rebuilding the field model clears selection: do it before applying evidence fields.
                            fieldsPanel.rebuildGroupedFields()
                            viewerController.clearSelection()
                            for (let name of fields) {
                                viewerController.setFieldSelected(name, true)
                                const group = name.substring(0, name.indexOf("."))
                                if (!viewerController.isGroupExpanded(group)) viewerController.toggleGroupExpanded(group)
                            }
                            mainTabBar.currentIndex = 0
                            logViewerChart.refreshBinChart()
                            if (time >= 0) logViewerChart.setSharedCursor(time)
                        }
                    }
                }
            }

            readonly property bool _xAxisShowLocalTime: QGroundControl.settingsManager.logViewerSettings.xAxisShowLocalTime.rawValue

            readonly property bool isFirmwareLog: viewerController.sourceType === LogViewerController.Bin
                                             || viewerController.sourceType === LogViewerController.ULog

            // Cancel any in-flight async parse before QML starts tearing down the tree.
            // Without this, the background thread can emit signals (parseProgressChanged,
            // parseFileFinished) into partially-destroyed QML objects, causing a
            // QQmlData::disconnectNotifiers crash.
            Component.onDestruction: fileParser.clear()

            function clearLoadedLogState(clearControllerState) {
                replayController.isPlaying = false
                replayController.link = null
                fileParser.clear()
                viewerController.setPlottableFields([])
                viewerController.clearSelection()
                _parametersTab.applyFilter()
                logViewerChart.clearMarker()
                logViewerChart.refreshBinChart()
                if (clearControllerState) {
                    viewerController.clear()
                }
            }

            function loadBinFile(file) {
                if (viewerController.hasLoadedLog) {
                    // Match explicit "Clear" behavior before loading replacement .bin file.
                    clearLoadedLogState(true)
                }
                pendingBinFile = file
                fileParser.startParsingAsync(file)
            }

            LogViewerController {
                id: viewerController
            }

            LogFileParser {
                id: fileParser
            }

            Connections {
                target: fileParser
                ignoreUnknownSignals: true

                function onParseFileFinished(filePath, ok, errorMessage) {
                    if (filePath !== pendingBinFile) {
                        return
                    }

                    if (!ok) {
                        assessAfterLoad = false
                        QGroundControl.showMessageDialog(logViewerPage, qsTr("Log Viewer"), errorMessage)
                        pendingBinFile = ""
                        return
                    }

                    fieldsPanel.rebuildGroupedFields()
                    _parametersTab.applyFilter()
                    viewerController.clearSelection()
                    logViewerChart.clearMarker()
                    logViewerChart.refreshBinChart()
                    Qt.callLater(logViewerChart.centerCursor)

                    const lowerPath = filePath.toLowerCase()
                    if (lowerPath.endsWith(".ulg")) {
                        viewerController.openULogFile(filePath)
                    } else {
                        viewerController.openBinLog(filePath)
                    }
                    pendingBinFile = ""
                    if (assessAfterLoad) {
                        assessAfterLoad = false
                        fileParser.assessLog()
                        assessmentFactory.open()
                    }
                }
            }

            LogReplayLinkController {
                id: replayController
            }

            Flow {
                objectName: "logViewerOpenActions"
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                spacing: ScreenTools.defaultFontPixelWidth

                QGCButton {
                    objectName: "logViewerOpenBin"
                    text: qsTr("Open .bin")
                    visible: QGroundControl.apmFirmwareSupported
                    onClicked: {
                        openDialog.nameFilters = ["DataFlash Logs (*.bin *.BIN *.log *.LOG)"]
                        assessAfterLoad = false
                        openDialog.openForLoad()
                    }
                }

                QGCButton {
                    objectName: "logViewerOpenULog"
                    text: qsTr("Open .ulg")
                    onClicked: {
                        openDialog.nameFilters = ["PX4 ULog Files (*.ulg *.ULG)"]
                        assessAfterLoad = false
                        openDialog.openForLoad()
                    }
                }

                QGCButton {
                    objectName: "logViewerOpenTLog"
                    text: qsTr("Open .tlog")
                    onClicked: {
                        const activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
                        if (activeVehicle && !activeVehicle.isOfflineEditingVehicle) {
                            QGroundControl.showMessageDialog(logViewerPage, qsTr("Log Viewer"), qsTr("Close active vehicle connections before starting telemetry replay."))
                            return
                        }
                        openDialog.nameFilters = ["Telemetry Logs (*.tlog *.TLOG)"]
                        assessAfterLoad = false
                        openDialog.openForLoad()
                    }
                }

                QGCButton {
                    objectName: "logViewerClear"
                    text: qsTr("Clear")
                    enabled: viewerController.hasLoadedLog
                    onClicked: {
                        clearLoadedLogState(true)
                    }
                }

                QGCButton {
                    objectName: "logViewerPIDReview"
                    text: qsTr("PID 分析（ArduPilot）")
                    visible: QGroundControl.apmFirmwareSupported
                    onClicked: Qt.openUrlExternally("https://firmware.ardupilot.org/Tools/WebTools/PIDReview/")
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("打开 ArduPilot 官方 PID Review 网页工具，并在浏览器中选择 DataFlash 日志。")
                }

                QGCLabel {
                    width: Math.min(implicitWidth, parent.width)
                    elide: Text.ElideMiddle
                    text: viewerController.hasLoadedLog ? viewerController.currentLogPath.replace(/.*[/\\]/, "") : qsTr("No log selected")
                }

                QGCLabel {
                    visible: viewerController.hasLoadedLog
                    text: qsTr("Start time:")
                }

                QGCLabel {
                    readonly property bool _hasStartTime: fileParser.startTime
                                                          && !isNaN(fileParser.startTime.getTime())
                                                          && fileParser.startTime.getTime() > 0
                    visible: viewerController.hasLoadedLog
                    text: _hasStartTime
                             ? Qt.formatDateTime(fileParser.startTime, Qt.locale().dateTimeFormat(Locale.ShortFormat))
                             : qsTr("N/A")
                }

                QGCLabel {
                    visible: viewerController.hasLoadedLog && fileParser.detectedVehicleType.length > 0
                    text: qsTr("Vehicle:")
                }

                QGCLabel {
                    visible: viewerController.hasLoadedLog && fileParser.detectedVehicleType.length > 0
                    text: fileParser.detectedVehicleType
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: fileParser.parsing
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("Loading...")
                }

                QGCSlider {
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    value: fileParser.parseProgress
                    enabled: false
                }
            }

            Flow {
                objectName: "logViewerAssessmentActions"
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                spacing: ScreenTools.defaultFontPixelWidth
                QGCButton {
                    objectName: "logViewerOpenAssess"
                    text: qsTr("导入并评估日志")
                    enabled: !fileParser.parsing && !fileParser.assessing
                    onClicked: {
                        assessAfterLoad = true
                        openDialog.nameFilters = ["Flight Logs (*.bin *.BIN *.log *.LOG *.ulg *.ULG)"]
                        openDialog.openForLoad()
                    }
                }
                QGCButton {
                    objectName: "logViewerAssess"
                    text: qsTr("评估当前日志")
                    enabled: isFirmwareLog && fileParser.parseComplete && !fileParser.parsing && !fileParser.assessing
                    onClicked: { fileParser.assessLog(); assessmentFactory.open() }
                }
                QGCCheckBox {
                    objectName: "logViewerChineseLabels"
                    text: qsTr("显示中文辅助说明")
                    checked: QGroundControl.settingsManager.logViewerSettings.showChineseLabels.rawValue
                    onClicked: QGroundControl.settingsManager.logViewerSettings.showChineseLabels.rawValue = checked
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: viewerController.sourceType === LogViewerController.TLog && replayController.link
                spacing: ScreenTools.defaultFontPixelWidth

                QGCButton {
                    text: replayController.isPlaying ? qsTr("Pause") : qsTr("Play")
                    onClicked: replayController.isPlaying = !replayController.isPlaying
                }

                QGCComboBox {
                    textRole: "text"
                    currentIndex: 3

                    model: ListModel {
                        ListElement { text: "0.1x";  value: 0.1  }
                        ListElement { text: "0.25x"; value: 0.25 }
                        ListElement { text: "0.5x";  value: 0.5  }
                        ListElement { text: "1x";    value: 1.0  }
                        ListElement { text: "2x";    value: 2.0  }
                        ListElement { text: "5x";    value: 5.0  }
                        ListElement { text: "10x";   value: 10.0 }
                    }

                    onActivated: (index) => replayController.playbackSpeed = model.get(index).value
                }

                QGCLabel { text: replayController.playheadTime }

                Slider {
                    id: _replaySlider
                    Layout.fillWidth: true
                    from: 0
                    to: 100

                    property bool _internalUpdate: false

                    Connections {
                        target: replayController
                        function onPercentCompleteChanged(percentComplete) {
                            _replaySlider._internalUpdate = true
                            _replaySlider.value = percentComplete
                            _replaySlider._internalUpdate = false
                        }
                    }

                    onValueChanged: {
                        if (!_internalUpdate) {
                            replayController.percentComplete = value
                        }
                    }
                }

                QGCLabel { text: replayController.totalTime }
            }

            QGCTabBar {
                id: mainTabBar
                objectName: "logViewerTabs"
                Layout.fillWidth: true

                QGCTabButton { text: qsTr("Charting") }
                QGCTabButton { text: qsTr("Map") }
                QGCTabButton { text: qsTr("Parameters") }
                QGCTabButton { text: qsTr("Messages") }
            }

            StackLayout {
                objectName: "logViewerTabContent"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 16
                currentIndex: mainTabBar.currentIndex

                // ---- Tab 0: Charting ----
                RowLayout {
                    objectName: "logViewerChartPane"
                    spacing: ScreenTools.defaultFontPixelWidth

                    // Left panel: stats + fields list
                    LogViewerFieldsPanel {
                        id: fieldsPanel
                        Layout.fillHeight: true
                        logParser: fileParser
                        logViewerController: viewerController
                        onClearSelectedRequested: logViewerChart.refreshBinChart()
                    }

                    // Right panel: chart + MAVLink inspector
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: qgcPal.windowShadeDark
                        radius: ScreenTools.defaultFontPixelWidth * 0.5

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelWidth
                            spacing: ScreenTools.defaultFontPixelHeight * 0.5

                            LogViewerChart {
                                id: logViewerChart
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: isFirmwareLog
                                logParser: fileParser
                                logViewerController: viewerController
                                xAxisShowLocalTime: _xAxisShowLocalTime

                                onCursorMoved: (t) => {
                                    _mapTab._markerVisible = true
                                    _mapTab._markerCoord   = fileParser.gpsCoordAt(t)
                                    if (_altChart.visible) _altChart.setSharedCursor(t)
                                }
                                onZoomApplied: (minX, maxX) => {
                                    if (_altChart.visible) _altChart.setSharedZoom(minX, maxX)
                                }
                            }

                            Loader {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                active: viewerController.sourceType === LogViewerController.TLog
                                source: "qrc:/qml/QGroundControl/AnalyzeView/MAVLinkInspector/MAVLinkInspectorPage.qml"
                            }
                        }
                    }
                }

                // ---- Tab 1: Map ----
                Item {
                    id: _mapTab
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // GPS path data
                    readonly property var _gpsPath: fileParser.parseComplete ? fileParser.gpsPath() : []
                    readonly property int _pathLen: (_gpsPath && _gpsPath.length) ? _gpsPath.length : 0
                    readonly property bool _hasPath: _pathLen >= 2
                    readonly property string _altFieldName: _hasPath ? fileParser.gpsAltitudeFieldName() : ""
                    readonly property bool _hasAltField: _altFieldName.length > 0

                    // Shared cursor state (driven by altitude chart, displayed on map)
                    property bool _markerVisible: false
                    property var _markerCoord: ({})

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // ---- Map ----
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            FlightMap {
                                id: _flightMap
                                anchors.fill: parent
                                mapName: "LogViewerMap"
                                allowGCSLocationCenter: true

                                readonly property var _path: _mapTab._gpsPath

                                function _fitPath() {
                                    const p = _mapTab._gpsPath
                                    if (!_mapTab._hasPath) return
                                    var minLat = p[0].latitude, maxLat = minLat
                                    var minLon = p[0].longitude, maxLon = minLon
                                    for (var i = 1; i < p.length; i++) {
                                        var c = p[i]
                                        if (c.latitude  < minLat) minLat = c.latitude
                                        if (c.latitude  > maxLat) maxLat = c.latitude
                                        if (c.longitude < minLon) minLon = c.longitude
                                        if (c.longitude > maxLon) maxLon = c.longitude
                                    }
                                    setVisibleRegion(QtPositioning.rectangle(
                                        QtPositioning.coordinate(maxLat, minLon),
                                        QtPositioning.coordinate(minLat, maxLon)))
                                }

                                Connections {
                                    target: fileParser
                                    function onParseCompleteChanged() {
                                        if (fileParser.parseComplete) Qt.callLater(_flightMap._fitPath)
                                    }
                                }

                                MapPolyline {
                                    line.width: 3
                                    line.color: QGroundControl.globalPalette.colorRed
                                    path: _flightMap._path
                                }

                                // Position dot driven by altitude chart cursor
                                MapQuickItem {
                                    readonly property var _coord: _mapTab._markerCoord
                                    visible: _mapTab._markerVisible && _mapTab._hasPath
                                                  && _coord && _coord.latitude !== undefined
                                    coordinate: (_coord && _coord.latitude !== undefined)
                                                  ? QtPositioning.coordinate(_coord.latitude, _coord.longitude)
                                                  : QtPositioning.coordinate(0, 0)
                                    anchorPoint: Qt.point(_posDot.width / 2, _posDot.height / 2)
                                    sourceItem: Rectangle {
                                        id: _posDot
                                        width: ScreenTools.defaultFontPixelHeight * 1.2
                                        height: width
                                        radius: width / 2
                                        color: QGroundControl.globalPalette.colorYellow
                                        border.color: "white"
                                        border.width: 2
                                    }
                                }

                                MapScale {
                                    anchors.margins: ScreenTools.defaultFontPixelWidth
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    mapControl: _flightMap
                                }
                            }

                            QGCLabel {
                                anchors.centerIn: parent
                                visible: fileParser.parseComplete && !_mapTab._hasPath
                                text: qsTr("No GPS data found in this log")
                                font.italic: true
                            }

                            QGCLabel {
                                anchors.centerIn: parent
                                visible: !fileParser.parseComplete
                                text: qsTr("Load a log file to view the flight path")
                                font.italic: true
                            }
                        }

                        // ---- Altitude chart ----
                        LogViewerAltChart {
                            id: _altChart
                            Layout.fillWidth: true
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 14
                            visible: _mapTab._hasAltField && _mapTab._hasPath
                            logParser: fileParser
                            altFieldName: _mapTab._altFieldName
                            xAxisShowLocalTime: _xAxisShowLocalTime

                            onMarkerChanged: (t) => {
                                _mapTab._markerVisible = true
                                _mapTab._markerCoord   = fileParser.gpsCoordAt(t)
                                logViewerChart.setSharedCursor(t)
                            }
                            onMarkerCleared: {
                                _mapTab._markerVisible = false
                            }
                            onZoomApplied: (minX, maxX) => {
                                logViewerChart.setSharedZoom(minX, maxX)
                            }
                        }
                    }
                }

                // ---- Tab 2: Parameters ----
                LogViewerParametersTab {
                    id: _parametersTab
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    logParser: fileParser
                }

                // ---- Tab 3: Messages ----
                LogViewerMessagesTab {
                    id: _messagesTab
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    logParser: fileParser
                }
            }

            QGCFileDialog {
                id: openDialog
                onRejected: assessAfterLoad = false
                title: qsTr("Select log file")
                folder: QGroundControl.settingsManager.appSettings.logSavePath
                selectFolder: false

                onAcceptedForLoad: (file) => {
                    const fileLower = file.toLowerCase()
                    if (fileLower.endsWith(".tlog")) {
                        if (viewerController.hasLoadedLog) {
                            clearLoadedLogState(true)
                        }
                        const replayLink = QGroundControl.linkManager.startLogReplay(file)
                        if (!replayLink) {
                            QGroundControl.showMessageDialog(
                                logViewerPage,
                                qsTr("Log Viewer"),
                                qsTr("Failed to start telemetry replay for the selected .tlog file.")
                            )
                            close()
                            return
                        }
                        replayController.link = replayLink
                        viewerController.openTLog(file)
                    } else {
                        loadBinFile(file)
                    }
                    close()
                }
            }
        }
    }
}
