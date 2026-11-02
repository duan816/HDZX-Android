import QtQuick
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    id: root
    objectName: "aiRawComparison"
    HQAITheme { id: theme }
    property var parser: null
    readonly property var fields: parser ? parser.plottableFields.filter(function(name) {
        return /^(ATT\.(Roll|Pitch|Yaw|DesRoll|DesPitch|DesYaw)|RATE\.|PID[RPY]\.|VIBE\.|vehicle_angular_velocity(?:_0)?\.|vehicle_rates_setpoint(?:_0)?\.)/.test(name)
    }) : []
    property var samples: []
    property var comparisonSamples: []
    property real minimum: NaN
    property real maximum: NaN
    property real comparisonMinimum: NaN
    property real comparisonMaximum: NaN
    readonly property string selectedField: fieldChoice.currentIndex >= 0 ? (fields[fieldChoice.currentIndex] || "") : ""
    readonly property string comparisonField: comparisonChoice.currentIndex > 0 ? (fields[comparisonChoice.currentIndex - 1] || "") : ""
    readonly property bool separateScales: comparisonField !== "" && family(selectedField) !== family(comparisonField)
    readonly property bool firstIsTarget: /^(ATT\.Des|RATE\.[RPY]Des$|vehicle_rates_setpoint)/.test(selectedField)
    readonly property bool secondIsTarget: /^(ATT\.Des|RATE\.[RPY]Des$|vehicle_rates_setpoint)/.test(comparisonField)
    readonly property color firstColor: firstIsTarget ? theme.amber : theme.cyan
    readonly property color secondColor: secondIsTarget || !firstIsTarget ? theme.amber : theme.cyan
    implicitHeight: 285
    onSelectedFieldChanged: {
        const pair = counterpart(selectedField)
        comparisonChoice.currentIndex = pair ? fields.indexOf(pair) + 1 : 0
        refresh()
    }
    onComparisonFieldChanged: refresh()
    function family(name) {
        if (name.startsWith("ATT.")) return "attitude"
        if (/^RATE\.[RPY](Des)?$/.test(name)) return "rate-deg"
        if (/^vehicle_(angular_velocity|rates_setpoint)/.test(name)) return "rate-rad"
        return name // Unknown or different units use independent, labelled scales.
    }
    function counterpart(name) {
        if (name.startsWith("ATT.Des")) return "ATT." + name.slice(7)
        if (/^ATT\.(Roll|Pitch|Yaw)$/.test(name)) return "ATT.Des" + name.slice(4)
        if (/^RATE\.[RPY]Des$/.test(name)) return name.slice(0, -3)
        if (/^RATE\.[RPY]$/.test(name)) return name + "Des"
        const axes = ["roll", "pitch", "yaw"]
        const match = /vehicle_angular_velocity(?:_0)?\.xyz\[(\d)\]/.exec(name)
        if (match) return fields.find(function(field) { return /^vehicle_rates_setpoint/.test(field) && field.endsWith("." + axes[Number(match[1])]) }) || ""
        for (let axis = 0; axis < 3; ++axis) {
            if (/^vehicle_rates_setpoint/.test(name) && name.endsWith("." + axes[axis]))
                return fields.find(function(field) { return /^vehicle_angular_velocity/.test(field) && field.endsWith(".xyz[" + axis + "]") }) || ""
        }
        return ""
    }
    function refresh() {
        samples = parser && selectedField ? parser.fieldSamplesFiltered(selectedField, parser.minTimestamp, parser.maxTimestamp, 400) : []
        comparisonSamples = parser && comparisonField ? parser.fieldSamplesFiltered(comparisonField, parser.minTimestamp, parser.maxTimestamp, 400) : []
        const limits = parser && selectedField ? parser.fieldMinMax(selectedField) : ({})
        const other = parser && comparisonField ? parser.fieldMinMax(comparisonField) : ({})
        minimum = limits.min === undefined ? NaN : limits.min
        maximum = limits.max === undefined ? NaN : limits.max
        comparisonMinimum = other.min === undefined ? NaN : other.min
        comparisonMaximum = other.max === undefined ? NaN : other.max
        plot.requestPaint()
    }
    QGCLabel { text: qsTr("真实日志曲线 · 双字段对照"); font.bold: true; color: theme.text }
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            QGCLabel { text: root.firstIsTarget ? qsTr("曲线 A · 目标 · 虚线") : qsTr("曲线 A · 实线"); color: root.firstColor }
            HQAICombo { id: fieldChoice; objectName: "aiRawFieldA"; Layout.fillWidth: true; model: root.fields }
        }
        ColumnLayout {
            Layout.fillWidth: true
            QGCLabel { text: root.secondIsTarget ? qsTr("曲线 B · 目标 · 虚线") : root.firstIsTarget ? qsTr("曲线 B · 实际 / 对照 · 实线") : qsTr("曲线 B · 对照 · 虚线"); color: root.secondColor }
            HQAICombo { id: comparisonChoice; objectName: "aiRawFieldB"; Layout.fillWidth: true; model: [qsTr("不叠加")].concat(root.fields) }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 175
        color: theme.background
        radius: 2
        border.color: theme.border
        Canvas {
            id: plot
            anchors.fill: parent
            anchors.margins: 10
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = theme.border
                ctx.lineWidth = 1
                for (let i = 1; i < 4; ++i) { ctx.beginPath(); ctx.moveTo(0, height * i / 4); ctx.lineTo(width, height * i / 4); ctx.stroke() }
                if (!root.parser) return
                const sharedMin = root.comparisonSamples.length && !root.separateScales ? Math.min(root.minimum, root.comparisonMinimum) : root.minimum
                const sharedMax = root.comparisonSamples.length && !root.separateScales ? Math.max(root.maximum, root.comparisonMaximum) : root.maximum
                const timeSpan = Math.max(0.00001, root.parser.maxTimestamp - root.parser.minTimestamp)
                function draw(points, low, high, color, dashed) {
                    if (points.length < 2 || !isFinite(low) || !isFinite(high)) return
                    const span = Math.max(0.00001, high - low)
                    ctx.strokeStyle = color; ctx.lineWidth = 1.5; ctx.setLineDash(dashed ? [5, 3] : [])
                    ctx.beginPath()
                    let started = false
                    for (const point of points) {
                        if (!isFinite(point.x) || !isFinite(point.y)) { started = false; continue }
                        const x = (point.x - root.parser.minTimestamp) / timeSpan * plot.width
                        const y = plot.height - 4 - (point.y - low) / span * (plot.height - 8)
                        if (started) ctx.lineTo(x, y)
                        else { ctx.moveTo(x, y); started = true }
                    }
                    ctx.stroke()
                }
                draw(root.samples, sharedMin, sharedMax, root.firstColor, root.firstIsTarget)
                draw(root.comparisonSamples, root.separateScales ? root.comparisonMinimum : sharedMin,
                    root.separateScales ? root.comparisonMaximum : sharedMax, root.secondColor, root.secondIsTarget || !root.firstIsTarget)
            }
        }
    }
    QGCLabel {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: theme.dim
        text: root.samples.length ? qsTr("A %1 [%2, %3]   B %4 [%5, %6] · 共用日志时间轴 · %7。抽样保留极值，不是频谱。")
            .arg(root.selectedField).arg(root.minimum.toFixed(3)).arg(root.maximum.toFixed(3))
            .arg(root.comparisonField || "--").arg(isFinite(root.comparisonMinimum) ? root.comparisonMinimum.toFixed(3) : "--")
            .arg(isFinite(root.comparisonMaximum) ? root.comparisonMaximum.toFixed(3) : "--")
            .arg(root.separateScales ? qsTr("单位可能不同，各用标注范围，不能比较幅值") : qsTr("相同字段类别共用纵轴，日志原单位"))
            : qsTr("日志没有提供对应字段，不能用 0 代替。")
        font.pointSize: ScreenTools.smallFontPointSize
    }
}
