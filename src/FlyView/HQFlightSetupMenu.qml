pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property url brandSource: "qrc:/res/HQLogo.png"
    signal closeRequested()
    signal pageRequested(string kind, int known)
    implicitWidth: ScreenTools.defaultFontPixelWidth * 43
    implicitHeight: ScreenTools.defaultFontPixelHeight * 34
    readonly property var groups: [
        {title: qsTr("基础配置"), entries: [
            {title:qsTr("飞控概览"), description:qsTr("状态、固件与配置完成情况"), kind:"summary", known:-1, icon:"overview"},
            {title:qsTr("传感器"), description:qsTr("加速度计、罗盘与传感器校准"), kind:"known", known:AutoPilotPlugin.KnownSensorsVehicleComponent, icon:"sensors"},
            {title:qsTr("遥控器"), description:qsTr("接收机、通道输入与摇杆校准"), kind:"known", known:AutoPilotPlugin.KnownRadioVehicleComponent, icon:"radio"}]},
        {title:qsTr("飞行与安全"), entries:[
            {title:qsTr("飞行模式"), description:qsTr("模式开关与控制方式"), kind:"known", known:AutoPilotPlugin.KnownFlightModesVehicleComponent, icon:"mode"},
            {title:qsTr("电源与电池"), description:qsTr("电压、电流与电池监测"), kind:"known", known:AutoPilotPlugin.KnownPowerVehicleComponent, icon:"power"},
            {title:qsTr("安全保护"), description:qsTr("故障保护与解锁条件"), kind:"known", known:AutoPilotPlugin.KnownSafetyVehicleComponent, icon:"safety"}]},
        {title:qsTr("高级工具"), entries:[
            {title:qsTr("存储卡与脚本"), description:qsTr("文件、LUA 上传与目录维护"), kind:"storage", known:-1, icon:"parameters"},
            {title:qsTr("扩展调参"), description:qsTr("PID、滤波与导航参数"), kind:"extended", known:-1, icon:"tuning"},
            {title:qsTr("AI 调参"), description:qsTr("DeepSeek 分析参数与飞行日志"), kind:"ai", known:-1, icon:"ai"},
            {title:qsTr("AI 日志分析"), description:qsTr("只分析 AP / PX4 日志证据"), kind:"aiLog", known:-1, icon:"ai"},
            {title:qsTr("全部参数"), description:qsTr("搜索与编辑原生飞控参数"), kind:"parameters", known:-1, icon:"parameters"}]}
    ]
    Rectangle {
        anchors.fill: parent
        radius: ScreenTools.defaultFontPixelHeight * 0.65
        gradient: Gradient { GradientStop { position:0; color:"#D90E2638" } GradientStop { position:1; color:"#C5081726" } }
        border.color: "#42608496"
    }
    MouseArea { anchors.fill:parent; onClicked: function(mouse) { mouse.accepted = true } }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.7
        spacing: ScreenTools.defaultFontPixelHeight * 0.6
        RowLayout {
            Layout.fillWidth: true
            Image { source:root.brandSource; sourceSize:Qt.size(ScreenTools.defaultFontPixelHeight*4.4,ScreenTools.defaultFontPixelHeight*4.4); mipmap:true; fillMode:Image.PreserveAspectFit; Layout.preferredWidth:ScreenTools.defaultFontPixelHeight*2.2; Layout.preferredHeight:ScreenTools.defaultFontPixelHeight*2.2 }
            ColumnLayout {
                Layout.fillWidth: true
                QGCLabel { Layout.fillWidth:true; wrapMode:Text.WordWrap; text:qsTr("飞行界面设置"); font.family:ScreenTools.hqUiFontFamily; font.weight:Font.DemiBold; font.pointSize:ScreenTools.defaultFontPointSize*1.15; color:"#E4F2F8" }
                QGCLabel { Layout.fillWidth:true; text:root.vehicle ? qsTr("当前主调试 · %1 号机").arg(root.vehicle.id) : qsTr("未连接飞控"); font.family:ScreenTools.hqUiFontFamily; font.pointSize:ScreenTools.smallFontPointSize; color:root.vehicle?"#60DFCF":"#FFB065" }
            }
            ToolButton {
                id: closeButton
                objectName:"setupMenuClose"
                Layout.preferredWidth:ScreenTools.minTouchPixels
                Layout.preferredHeight:ScreenTools.minTouchPixels
                onClicked:root.closeRequested()
                Accessible.name: qsTr("关闭飞行界面设置")
                contentItem:Item {
                    Rectangle { anchors.centerIn:parent; width:ScreenTools.defaultFontPixelHeight*0.7; height:1.5; rotation:45; color:"#A7C7D8" }
                    Rectangle { anchors.centerIn:parent; width:ScreenTools.defaultFontPixelHeight*0.7; height:1.5; rotation:-45; color:"#A7C7D8" }
                }
                background:Rectangle {
                    color: closeButton.down ? "#303B687D" : closeButton.hovered ? "#182D4B5E" : "transparent"
                    radius: width / 2
                    Behavior on color { ColorAnimation { duration: 140 } }
                    HQButtonRipple { control: closeButton }
                }
            }
        }
        Rectangle { Layout.fillWidth:true; Layout.preferredHeight:1; color:"#294558" }
        QGCFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: entriesColumn.implicitHeight
            ColumnLayout {
                id: entriesColumn
                width: parent.width
                spacing: ScreenTools.defaultFontPixelHeight * 0.55
                Repeater {
                    model: root.groups
                    ColumnLayout {
                        id: group
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelHeight * 0.35
                        QGCLabel { text:group.modelData.title; font.family:ScreenTools.hqUiFontFamily; color:"#79A6BD"; font.pointSize:ScreenTools.smallFontPointSize; font.weight:Font.Medium; Layout.topMargin:ScreenTools.defaultFontPixelHeight*0.3 }
                        Repeater {
                            model: group.modelData.entries
                            QGCButton {
                                id: entry
                                required property var modelData
                                objectName: "setupEntry_" + modelData.title
                                Layout.fillWidth: true
                                implicitHeight: Math.max(ScreenTools.minTouchPixels, row.implicitHeight + ScreenTools.defaultFontPixelHeight)
                                onClicked: {
                                    if (!root.vehicle) {
                                        QGroundControl.showMessageDialog(root,qsTr("尚未连接飞控"),qsTr("请连接飞控并等待参数下载完成。"),Dialog.Ok)
                                        return
                                    }
                                    root.pageRequested(modelData.kind,modelData.known)
                                }
                                background: Rectangle {
                                    radius: ScreenTools.defaultFontPixelHeight*0.5
                                    color: entry.down?"#303B687D":entry.hovered?"#183B687D":"transparent"
                                    scale: entry.down?0.985:1
                                    Behavior on color { ColorAnimation { duration:140 } }
                                    Behavior on scale { NumberAnimation { duration:150; easing.type:Easing.OutCubic } }
                                    HQButtonRipple { control: entry }
                                    Rectangle { anchors.bottom:parent.bottom; anchors.left:parent.left; anchors.right:parent.right; height:1; color:"#2338596B" }
                                }
                                contentItem: RowLayout {
                                    id: row
                                    spacing: ScreenTools.defaultFontPixelHeight*0.6
                                    Rectangle {
                                        Layout.preferredWidth: ScreenTools.defaultFontPixelHeight*2
                                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight*2
                                        color:"transparent"
                                        HQSetupIcon { anchors.centerIn:parent; width:parent.width*0.65; height:width; kind:entry.modelData.icon }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth:true
                                        spacing:ScreenTools.defaultFontPixelHeight*0.15
                                        QGCLabel { Layout.fillWidth:true; text:entry.modelData.title; color:"#E3F0F5"; font.family:ScreenTools.hqUiFontFamily; font.weight:Font.Medium }
                                        QGCLabel { Layout.fillWidth:true; text:entry.modelData.description; color:"#8BAFC0"; font.family:ScreenTools.hqUiFontFamily; font.pointSize:ScreenTools.smallFontPointSize; wrapMode:Text.WordWrap }
                                    }
                                    QGCLabel { text:"›"; color:"#7DADBF"; font.pointSize:ScreenTools.defaultFontPointSize*1.5 }
                                }
                            }
                        }
                    }
                }
            }
        }
        QGCLabel { Layout.fillWidth:true; text:qsTr("侧栏可左右停靠、拖动调宽。"); font.family:ScreenTools.hqUiFontFamily; font.pointSize:ScreenTools.smallFontPointSize; color:"#85A7B9"; wrapMode:Text.WordWrap }
    }
}
