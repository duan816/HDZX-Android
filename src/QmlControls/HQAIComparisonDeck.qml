pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QGroundControl.Controls

ColumnLayout {
    id: root
    HQAITheme { id: theme }
    property var parser: null
    property bool rangeEditable: true
    property alias beginText: startField.text
    property alias endText: endField.text
    signal rangeEdited(string begin, string end)
    readonly property var fields: parser ? parser.plottableFields : []
    readonly property real start: startField.text === "" ? (parser ? parser.minTimestamp : 0) : Number(startField.text)
    readonly property real end: endField.text === "" ? (parser ? parser.maxTimestamp : 0) : Number(endField.text)
    readonly property bool validRange: isFinite(start) && isFinite(end) && end > start
    function pick(names) { for (const name of names) if (fields.indexOf(name) >= 0) return name; return "" }
    readonly property var axes: [
        {name: qsTr("横滚 / ROLL"), actual: pick(["RATE.R", "vehicle_angular_velocity.xyz[0]", "vehicle_angular_velocity_0.xyz[0]"]), target: pick(["RATE.RDes", "vehicle_rates_setpoint.roll", "vehicle_rates_setpoint_0.roll"])},
        {name: qsTr("俯仰 / PITCH"), actual: pick(["RATE.P", "vehicle_angular_velocity.xyz[1]", "vehicle_angular_velocity_0.xyz[1]"]), target: pick(["RATE.PDes", "vehicle_rates_setpoint.pitch", "vehicle_rates_setpoint_0.pitch"])},
        {name: qsTr("偏航 / YAW"), actual: pick(["RATE.Y", "vehicle_angular_velocity.xyz[2]", "vehicle_angular_velocity_0.xyz[2]"]), target: pick(["RATE.YDes", "vehicle_rates_setpoint.yaw", "vehicle_rates_setpoint_0.yaw"])}
    ]
    RowLayout {
        Layout.fillWidth: true
        QGCLabel { text: qsTr("日志时间 / s"); Layout.fillWidth: true; font.family: theme.fontFamily; font.pointSize: 9; color: theme.dim }
        QGCLabel { text: qsTr("┄ 目标"); color: theme.amber; font.pointSize: 9 }
        QGCLabel { text: qsTr("━ 实际"); color: theme.cyan; font.pointSize: 9 }
    }
    RowLayout {
        Layout.fillWidth: true
        HQAIInput { id: startField; objectName: "aiChartBegin"; Layout.fillWidth: true; monospace: true; enabled: root.rangeEditable; placeholderText: root.parser ? root.parser.minTimestamp.toFixed(1) : "--"; onEditingFinished: root.rangeEdited(text, endField.text) }
        QGCLabel { text: "—"; color: theme.dim }
        HQAIInput { id: endField; objectName: "aiChartEnd"; Layout.fillWidth: true; monospace: true; enabled: root.rangeEditable; placeholderText: root.parser ? root.parser.maxTimestamp.toFixed(1) : "--"; onEditingFinished: root.rangeEdited(startField.text, text) }
    }
    Repeater {
        model: root.axes
        ColumnLayout {
            id: axis
            required property var modelData
            Layout.fillWidth: true
            property var actual: root.parser && root.validRange && modelData.actual ? root.parser.fieldSamplesFiltered(modelData.actual, root.start, root.end, 300) : []
            property var desired: root.parser && root.validRange && modelData.target ? root.parser.fieldSamplesFiltered(modelData.target, root.start, root.end, 300) : []
            readonly property var range: {
                let minimum = Infinity, maximum = -Infinity
                for (const point of actual.concat(desired)) if (isFinite(point.y)) { minimum = Math.min(minimum, point.y); maximum = Math.max(maximum, point.y) }
                return {min: minimum, max: maximum}
            }
            onActualChanged: plot.requestPaint()
            onDesiredChanged: plot.requestPaint()
            QGCLabel {
                Layout.fillWidth: true
                text: axis.modelData.name + "  ·  " + (axis.modelData.actual.indexOf("RATE.") === 0 ? "°/s" : axis.modelData.actual ? "rad/s" : qsTr("未上报"))
                font.pointSize: 9
                font.family: theme.fontFamily
                color: theme.dim
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 94
                radius: 2
                color: theme.background
                border.color: theme.border
                Canvas {
                    id: plot
                    anchors.fill: parent
                    anchors.margins: 8
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.lineWidth = 1
                        ctx.strokeStyle = theme.border
                        for (let i = 1; i < 4; ++i) { ctx.beginPath(); ctx.moveTo(0, height * i / 4); ctx.lineTo(width, height * i / 4); ctx.stroke() }
                        if (!root.validRange || !isFinite(axis.range.min)) return
                        const span = Math.max(0.000001, axis.range.max - axis.range.min)
                        function draw(points, color, dashed) {
                            ctx.strokeStyle = color
                            ctx.lineWidth = 1.4
                            ctx.beginPath()
                            let started = false
                            for (let i = 0; i < points.length; ++i) {
                                const point = points[i]
                                if (!isFinite(point.x) || !isFinite(point.y)) { started = false; continue }
                                const x = (point.x - root.start) / (root.end - root.start) * width
                                const y = height - 2 - (point.y - axis.range.min) / span * (height - 4)
                                if (!started || (dashed && i % 6 < 2)) ctx.moveTo(x, y)
                                else ctx.lineTo(x, y)
                                started = true
                            }
                            ctx.stroke()
                        }
                        draw(axis.desired, theme.amber, true)
                        draw(axis.actual, theme.cyan, false)
                    }
                }
                QGCLabel { anchors.centerIn: parent; visible: axis.actual.length === 0; color: theme.dim; font.pointSize: 9; text: root.validRange ? qsTr("缺少对应实际角速度字段") : qsTr("请选择有效时间范围") }
            }
            QGCLabel {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pointSize: 8
                font.family: theme.monoFamily
                color: theme.dim
                text: axis.actual.length ? axis.modelData.actual + " / " + (axis.desired.length ? axis.modelData.target : qsTr("目标未上报")) + "  ·  " + axis.range.min.toFixed(2) + " ~ " + axis.range.max.toFixed(2) : qsTr("缺失值不会画成 0")
            }
        }
    }
    QGCLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pointSize: 8; color: theme.dim; text: root.rangeEditable ? qsTr("结束编辑时间范围后重新计算同一区间评分与分析证据。排除段不参与评分，原始曲线仍保留供审核；参数写入不会自动改善曲线。") : qsTr("真实目标 / 实际数据；评分按本次报告的有效动作计算，参数写入不会自动改善曲线。") }
}
