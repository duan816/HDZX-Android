import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FlightMap

TransectStyleComplexItemEditor {
    transectAreaDefinitionComplete: missionItem.surveyAreaPolygon.isValid
    transectAreaDefinitionHelp:     qsTr("Use the Polygon Tools to create the polygon which outlines your survey area.")
    transectValuesHeaderName:       qsTr("Transects")
    transectValuesComponent:        _transectValuesComponent
    presetsTransectValuesComponent: _transectValuesComponent
    waypointEditorComponent: _waypointEditorComponent

    property real   _margin:        ScreenTools.defaultFontPixelWidth / 2
    property var    _missionItem:   missionItem

    Component {
        id: _transectValuesComponent

        GridLayout {
            Layout.fillWidth:   true
            columnSpacing:      _margin
            rowSpacing:         _margin
            columns:            2

            QGCLabel { text: qsTr("Angle") }
            FactTextField {
                fact:                   missionItem.gridAngle
                Layout.fillWidth:       true
                onUpdated:              angleSlider.value = missionItem.gridAngle.value
            }

            QGCSlider {
                id:                     angleSlider
                from:           0
                to:           359
                stepSize:               1
                Layout.fillWidth:       true
                Layout.columnSpan:      2
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                onValueChanged:         missionItem.gridAngle.value = value
                Component.onCompleted:  value = missionItem.gridAngle.value
                live: true
            }

            QGCLabel {
                text:       qsTr("Turnaround dist")
                visible:    !forPresets
            }
            FactTextField {
                Layout.fillWidth:   true
                fact:               missionItem.turnAroundDistance
                visible:            !forPresets
            }

            QGCOptionsComboBox {
                Layout.columnSpan:  2
                Layout.fillWidth:   true
                visible:            !forPresets

                model: [
                    {
                        text:       qsTr("Hover and capture image"),
                        fact:       missionItem.hoverAndCapture,
                        enabled:    missionItem.cameraCalc.distanceMode === QGroundControl.AltitudeFrameRelative || missionItem.cameraCalc.distanceMode === QGroundControl.AltitudeFrameAbsolute,
                        visible:    missionItem.hoverAndCaptureAllowed
                    },
                    {
                        text:       qsTr("Refly at 90 deg offset"),
                        fact:       missionItem.refly90Degrees,
                        enabled:    missionItem.cameraCalc.distanceMode !== QGroundControl.AltitudeFrameCalcAboveTerrain,
                        visible:    true
                    },
                    {
                        text:       qsTr("Images in turnarounds"),
                        fact:       missionItem.cameraTriggerInTurnAround,
                        enabled:    missionItem.hoverAndCaptureAllowed ? !missionItem.hoverAndCapture.rawValue : true,
                        visible:    true
                    },
                    {
                        text:       qsTr("Fly alternate transects"),
                        fact:       missionItem.flyAlternateTransects,
                        enabled:    true,
                        visible:    _vehicle ? (_vehicle.fixedWing || _vehicle.vtol) : false
                    }
                ]
            }

            QGCButton {
                objectName: "hdzxConvertSurveyButton"
                Layout.columnSpan: 2
                Layout.fillWidth: true
                visible: !forPresets
                text: qsTr("转为可编辑航点")
                onClicked: {
                    const controller = _missionController
                    const survey = missionItem
                    QGroundControl.showMessageDialog(mainWindow, qsTr("转换勘测航线"),
                        qsTr("保留当前航点的位置、高度和拍照指令，转换后可逐点拖动、修改参数。转换后不再随勘测区域自动重排。建议先保存原始计划，以便重新规划。是否转换？"),
                        Dialog.Yes | Dialog.No,
                        function() {
                            const error = controller.convertSurveyToWaypoints(survey)
                            if (error.length) QGroundControl.showMessageDialog(mainWindow, qsTr("无法转换"), error)
                        })
                }
            }
        }
    }

    Component {
        id: _waypointEditorComponent
        ColumnLayout {
            id: waypointPanel
            property bool expanded: true
            readonly property var editor: missionItem.generatedWaypointEditor
            Layout.fillWidth: true
            QGCButton {
                objectName: "hdzxSurveyWaypointHeader"
                Layout.fillWidth: true
                text: (waypointPanel.expanded ? "▾ " : "▸ ") + qsTr("勘测航点（%1）").arg(missionItem.generatedWaypoints.length)
                onClicked: waypointPanel.expanded = !waypointPanel.expanded
            }
            QGCLabel {
                Layout.fillWidth: true
                visible: waypointPanel.expanded
                text: qsTr("上方修改勘测整体设置，下方航点同步更新；已微调的点按原位置尽量保留。编号与真实任务一致，拍照指令另占编号。")
                wrapMode: Text.Wrap
                font.pointSize: ScreenTools.smallFontPointSize
            }
            QGCLabel {
                Layout.fillWidth: true
                visible: waypointPanel.expanded && missionItem.unmatchedWaypointAdjustments > 0
                text: qsTr("有 %1 个微调点未匹配或高度参考系已改变，请复核；原微调记录仍保留在计划中。").arg(missionItem.unmatchedWaypointAdjustments)
                color: QGroundControl.globalPalette.warningText
                wrapMode: Text.Wrap
            }
            ListView {
                objectName: "hdzxSurveyWaypointList"
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? Math.min(contentHeight, ScreenTools.defaultFontPixelHeight * 8) : 0
                visible: waypointPanel.expanded
                clip: true
                model: missionItem.generatedWaypoints
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: QGCButton {
                    required property var modelData
                    width: ListView.view.width
                    checked: !!waypointPanel.editor && waypointPanel.editor.sequenceNumber === modelData.sequenceNumber
                    text: qsTr("#%1  航点    高度 %2 m").arg(modelData.sequenceNumber).arg(Number(modelData.altitude).toFixed(1))
                    onClicked: {
                        const error = missionItem.selectGeneratedWaypoint(modelData.sequenceNumber)
                        if (error.length) QGroundControl.showMessageDialog(mainWindow, qsTr("无法编辑航点"), error)
                    }
                }
            }
            MissionQuickEditor {
                objectName: "hdzxSurveyPointEditor"
                Layout.fillWidth: true
                missionItem: waypointPanel.expanded ? waypointPanel.editor : null
                maximumHeight: ScreenTools.defaultFontPixelHeight * 16
                onSelectStep: (step) => {
                    const points = _missionItem.generatedWaypoints
                    const index = points.findIndex(point => point.sequenceNumber === waypointPanel.editor.sequenceNumber) + step
                    if (index >= 0 && index < points.length) _missionItem.selectGeneratedWaypoint(points[index].sequenceNumber)
                }
            }
        }
    }

    KMLOrSHPFileDialog {
        id:             kmlOrSHPLoadDialog
        title:          qsTr("Select Polygon File")

        onAcceptedForLoad: (file) => {
            missionItem.surveyAreaPolygon.loadKMLOrSHPFile(file)
            missionItem.resetState = false
            //editorMap.mapFitFunctions.fitMapViewportTomissionItems()
            close()
        }
    }
}
