import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    id: root

    property var missionItem: null
    property real maximumHeight: ScreenTools.defaultFontPixelHeight * 20
    property bool expanded: true
    property bool showHelp: false
    property string errorText: ""
    readonly property bool editable: missionItem && missionItem.isSimpleItem && missionItem.sequenceNumber > 0
    readonly property var parameters: editable ? missionItem.quickEditParameters : []
    signal selectStep(int step)

    visible: editable
    implicitHeight: visible ? header.height + (expanded ? Math.min(maximumHeight, body.contentHeight) : 0) : 0
    height: implicitHeight
    clip: true
    Behavior on height {
        enabled: root.visible
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    function parameterLabel(record) {
        const command = missionItem ? missionItem.command : -1
        const key = command + ":" + record.parameter
        const labels = {
            "16:1": qsTr("Hold（到点停留时间）"),
            "16:2": qsTr("Acceptance（到达半径）"),
            "16:4": qsTr("Yaw（航向角）"),
            "18:1": qsTr("Turns（绕圈圈数）"),
            "19:1": qsTr("Time（停留秒数）"),
            "82:1": qsTr("Hold（到点停留时间）"),
            "112:1": qsTr("Delay（延时秒数）"),
            "115:1": qsTr("Heading（目标航向）"),
            "115:2": qsTr("Rate（转向速度）"),
            "177:1": qsTr("Target（跳转编号）"),
            "177:2": qsTr("Repeat（重复次数）"),
            "178:2": qsTr("Speed（目标速度）")
        }
        if (missionItem && missionItem.showLoiterRadius && record.parameter === (command === 31 ? 2 : 3)) {
            return qsTr("Radius（绕圈半径）")
        }
        return labels[key] || record.label + " · P" + record.parameter
    }

    function commit(parameter, text, target, command) {
        // Focus loss during selection/command changes must never edit the replacement item.
        if (!editable || !target || target !== missionItem || target.command !== command) return
        errorText = target.setQuickEditParameter(parameter, text)
    }

    function changeDirection(clockwise) {
        if (!editable || !missionItem.showLoiterRadius) return
        const parameter = missionItem.command === 31 ? 2 : 3
        commit(parameter, String(Math.abs(missionItem.loiterRadius) * (clockwise ? 1 : -1)),
               missionItem, missionItem.command)
    }

    onMissionItemChanged: errorText = ""
    Connections {
        target: root.missionItem
        ignoreUnknownSignals: true
        function onCommandChanged() { root.errorText = "" }
    }

    QGCPalette { id: palette }
    QGCButton {
        id: header
        width: parent.width
        text: (root.expanded ? "▾ " : "▸ ") + qsTr("Quick edit（快捷编辑）")
        onClicked: root.expanded = !root.expanded
    }

    Rectangle {
        anchors.top: header.bottom
        width: parent.width
        height: Math.max(0, root.height - header.height)
        visible: height > 0
        enabled: root.expanded
        color: palette.windowShadeDark

        Flickable {
            id: body
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: fields.implicitHeight + fields.y * 2
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: fields
                x: ScreenTools.defaultFontPixelWidth * 0.6
                y: ScreenTools.defaultFontPixelHeight * 0.3
                width: parent.width - x * 2
                spacing: ScreenTools.defaultFontPixelHeight * 0.3

                QGCLabel {
                    Layout.fillWidth: true
                    text: root.editable ? "#" + root.missionItem.sequenceNumber + " · " + root.missionItem.commandName : ""
                    color: palette.planWaypointSelected
                    wrapMode: Text.WordWrap
                }
                RowLayout {
                    Layout.fillWidth: true
                    QGCButton { objectName: "hdzxPreviousMissionItem"; Layout.fillWidth: true; text: qsTr("上一项"); onClicked: root.selectStep(-1) }
                    QGCButton { objectName: "hdzxNextMissionItem"; Layout.fillWidth: true; text: qsTr("下一项"); onClicked: root.selectStep(1) }
                }
                QGCLabel { text: qsTr("Altitude（高度）"); visible: root.editable && root.missionItem.specifiesAltitude }
                FactTextField {
                    objectName: "hdzxQuickAltitude"
                    Layout.fillWidth: true
                    fact: root.editable ? root.missionItem.altitude : null
                    visible: root.editable && root.missionItem.specifiesAltitude
                }
                QGCLabel {
                    Layout.fillWidth: true
                    visible: root.editable && root.missionItem.specifiesAltitude
                    text: qsTr("高度沿用该任务的高度参考系，不改变相对/绝对高度设置。")
                    font.pointSize: ScreenTools.smallFontPointSize
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: root.parameters
                    ColumnLayout {
                        id: parameterRow
                        required property var modelData
                        readonly property var record: modelData
                        property var targetItem: null
                        property int targetCommand: -1
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelHeight * 0.15
                        Component.onCompleted: {
                            targetItem = root.missionItem
                            targetCommand = targetItem ? targetItem.command : -1
                        }
                        QGCLabel { Layout.fillWidth: true; text: root.parameterLabel(parameterRow.record); wrapMode: Text.WordWrap }
                        QGCComboBox {
                            Layout.fillWidth: true
                            visible: parameterRow.record.enumStrings.length > 0
                            model: parameterRow.record.enumStrings
                            currentIndex: parameterRow.record.enumValues.indexOf(Number(parameterRow.record.fact.rawValue))
                            onActivated: (index) => root.commit(parameterRow.record.parameter,
                                String(parameterRow.record.enumValues[index]), parameterRow.targetItem, parameterRow.targetCommand)
                        }
                        QGCTextField {
                            objectName: "quickParameter_" + parameterRow.record.parameter
                            Layout.fillWidth: true
                            visible: parameterRow.record.enumStrings.length === 0
                            numericValuesOnly: true
                            showUnits: true
                            unitsLabel: parameterRow.record.units
                            text: isNaN(Number(parameterRow.record.fact.rawValue)) ? "NaN" : String(parameterRow.record.fact.rawValue)
                            onEditingFinished: root.commit(parameterRow.record.parameter, text,
                                parameterRow.targetItem, parameterRow.targetCommand)
                        }
                        QGCCheckBox {
                            visible: parameterRow.record.nanAllowed
                            text: qsTr("Use default（使用默认策略）")
                            checked: isNaN(Number(parameterRow.record.fact.rawValue))
                            onClicked: root.commit(parameterRow.record.parameter, checked ? "NaN" : "0",
                                parameterRow.targetItem, parameterRow.targetCommand)
                        }
                    }
                }

                QGCComboBox {
                    objectName: "quickLoiterDirection"
                    Layout.fillWidth: true
                    visible: root.editable && root.missionItem.showLoiterRadius
                    model: [qsTr("Clockwise（顺时针）"), qsTr("Counter-clockwise（逆时针）")]
                    currentIndex: root.editable && root.missionItem.loiterRadius < 0 ? 1 : 0
                    onActivated: (index) => root.changeDirection(index === 0)
                }
                QGCLabel {
                    Layout.fillWidth: true
                    visible: root.editable && root.missionItem.showLoiterRadius
                    text: root.missionItem && root.missionItem.command === 18
                        ? qsTr("半径正值顺时针、负值逆时针；AP 多旋翼半径 0 表示原地旋转。圈数大于 1 时使用整数。圆形仅作规划预览。")
                        : qsTr("正半径顺时针、负半径逆时针。圆形仅作规划预览，实际轨迹由固件和机型决定。")
                    wrapMode: Text.WordWrap
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                QGCLabel {
                    Layout.fillWidth: true
                    visible: root.errorText.length > 0
                    text: root.errorText
                    color: palette.warningText
                    wrapMode: Text.WordWrap
                }
                QGCButton {
                    Layout.fillWidth: true
                    text: qsTr("Help（命令说明）")
                    onClicked: root.showHelp = !root.showHelp
                }
                QGCLabel {
                    Layout.fillWidth: true
                    visible: root.showHelp
                    text: root.editable ? root.missionItem.commandDescription : ""
                    wrapMode: Text.WordWrap
                }
                QGCButton {
                    Layout.fillWidth: true
                    visible: root.showHelp
                    text: qsTr("打开 AP 航线教程")
                    onClicked: Qt.openUrlExternally("https://docs.01aero.cn/docs/wpdcp")
                }
                QGCLabel {
                    Layout.fillWidth: true
                    text: qsTr("只修改本地计划；保存后仍需手动上传。未列出的参数继续在任务卡片中编辑。")
                    wrapMode: Text.WordWrap
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
        }
    }
}
