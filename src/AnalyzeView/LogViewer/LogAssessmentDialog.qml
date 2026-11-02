pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

QGCPopupDialog {
    id: root
    required property var logParser
    property var selectedIds: []
    signal showFieldsRequested(var fields, real time)
    title: qsTr("Log Assessment（日志一键评估 · 仅供参考）")
    buttons: Dialog.Close
    QGCPalette { id: palette }

    ColumnLayout {
        width: Math.min(root.maxContentAvailableWidth, ScreenTools.defaultFontPixelWidth * 110)
        spacing: ScreenTools.defaultFontPixelHeight * 0.5
        QGCLabel {
            objectName: "assessmentStatus"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: !root.logParser ? qsTr("无法读取当前日志，请关闭此窗口并重新载入日志。")
                : root.logParser.assessing ? qsTr("正在本地分析，请稍候…")
                : root.logParser.assessment.length > 0
                    ? qsTr("评估完成，共 %1 项。勾选排查项后查看对应曲线。仅供参考，不修改飞控参数。").arg(root.logParser.assessment.length)
                    : qsTr("暂无评估结果，请关闭此窗口并重新评估已载入的日志。")
        }
        QGCButton {
            objectName: "showAssessmentCurves"
            text: qsTr("Show Selected Curves（查看所选曲线）")
            enabled: root.logParser && root.selectedIds.length > 0 && !root.logParser.assessing
            onClicked: {
                const fields = []
                let time = -1
                for (let item of root.logParser.assessment) {
                    if (root.selectedIds.indexOf(item.id) < 0) continue
                    for (let name of item.fields) {
                        if (root.logParser.plottableFields.indexOf(name) >= 0 && fields.indexOf(name) < 0) fields.push(name)
                    }
                    if (time < 0 && item.time >= 0) time = item.time
                }
                root.showFieldsRequested(fields, time)
                root.close()
            }
        }
        ScrollView {
            id: findingsView
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(root.maxContentAvailableHeight * 0.7, ScreenTools.defaultFontPixelHeight * 28)
            clip: true
            ColumnLayout {
                width: findingsView.availableWidth
                spacing: ScreenTools.defaultFontPixelHeight
                Repeater {
                    id: findings
                    objectName: "assessmentFindings"
                    model: root.logParser ? root.logParser.assessment : []
                    Rectangle {
                        id: finding
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: details.implicitHeight + ScreenTools.defaultFontPixelHeight
                        color: palette.windowShade
                        radius: ScreenTools.defaultFontPixelWidth * 0.5
                        ColumnLayout {
                            id: details
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.5
                            QGCCheckBox {
                                id: chooseFinding
                                objectName: "assessmentChoice_" + finding.modelData.id
                                Layout.fillWidth: true
                                text: (finding.modelData.status === "suspect" ? qsTr("[排查提示] ") : finding.modelData.status === "missing" ? qsTr("[无法评估] ") : qsTr("[记录参考] ")) + finding.modelData.title
                                enabled: finding.modelData.fields.length > 0
                                checked: root.selectedIds.indexOf(finding.modelData.id) >= 0
                                onClicked: {
                                    const ids = root.selectedIds.filter(id => id !== finding.modelData.id)
                                    if (chooseFinding.checked) ids.push(finding.modelData.id)
                                    root.selectedIds = ids
                                }
                            }
                            QGCLabel {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                                text: finding.modelData.evidence
                                color: finding.modelData.status === "suspect" ? palette.warningText : palette.text
                            }
                            QGCLabel { Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText; text: finding.modelData.advice }
                            QGCLabel { Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; textFormat: Text.PlainText; text: qsTr("Fields（对应字段）: ") + finding.modelData.fields.join(", "); visible: finding.modelData.fields.length > 0 }
                            QGCButton { text: qsTr("Reference（配置与诊断依据）"); visible: finding.modelData.source.length > 0; onClicked: Qt.openUrlExternally(finding.modelData.source) }
                        }
                    }
                }
            }
        }
    }
}
