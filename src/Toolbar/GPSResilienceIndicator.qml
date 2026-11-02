pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import "HQGnssIntegrity.js" as Integrity

Item {
    id: control
    width: height
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var _gpsAggregate: _activeVehicle ? _activeVehicle.gpsAggregate : null
    property bool showIndicator: Integrity.shouldShow(_gpsAggregate)
    visible: showIndicator
    QGCPalette { id: palette }
    QGCColoredImage {
        anchors.centerIn: parent
        width: parent.height*0.95; height:width
        source:"/qmlimages/GpsAuthentication.svg"
        visible: Integrity.authKnown(control._gpsAggregate)
        color: {
            const a=Integrity.state(control._gpsAggregate,"authenticationState")
            return a===1?palette.colorYellow:a===2?palette.colorRed:a===3?palette.colorGreen:palette.text
        }
    }
    QGCColoredImage {
        anchors.centerIn:parent
        width:parent.height*0.55; height:width
        source:"/qmlimages/GpsInterference.svg"
        visible:Integrity.threat(control._gpsAggregate)>0
        color:Integrity.threat(control._gpsAggregate)===3?palette.colorRed:Integrity.threat(control._gpsAggregate)===2?palette.colorOrange:palette.colorGreen
    }
    MouseArea { anchors.fill:parent; onClicked:mainWindow.showIndicatorDrawer(statusPage,control) }
    Component {
        id:statusPage
        ToolIndicatorPage {
            contentComponent:Component {
                ColumnLayout {
                    spacing:ScreenTools.defaultFontPixelHeight*0.6
                    QGCLabel { text:qsTr("GNSS 抗干扰、欺骗与信号认证"); font.bold:true }
                    Repeater {
                        model: [control._gpsAggregate,control._activeVehicle?control._activeVehicle.gps:null,control._activeVehicle?control._activeVehicle.gps2:null]
                        ColumnLayout {
                            id: group
                            required property var modelData
                            required property int index
                            visible:Integrity.shouldShow(modelData)
                            QGCLabel { text:group.index===0?qsTr("全局状态"):qsTr("GPS %1").arg(group.index); font.bold:true }
                            LabelledLabel { label:qsTr("干扰"); labelText:Integrity.description(group.modelData,"jammingState") }
                            LabelledLabel { label:qsTr("欺骗"); labelText:Integrity.description(group.modelData,"spoofingState") }
                            LabelledLabel { label:qsTr("信号认证"); labelText:Integrity.description(group.modelData,"authenticationState"); visible:Integrity.authKnown(group.modelData) }
                        }
                    }
                    QGCLabel { Layout.maximumWidth:ScreenTools.defaultFontPixelWidth*46; wrapMode:Text.WordWrap; text:qsTr("仅显示接收机真实上报的状态。信号认证包括 OSNMA 等机制；此消息不标明认证协议，不能据此断言设备支持 OSNMA。未上报认证能力时不显示认证入口，但实际扰骗告警仍会提示。"); font.pointSize:ScreenTools.smallFontPointSize }
                    QGCLabel { text:qsTr("黄：初始化  ·  红：认证失败  ·  绿：认证成功  ·  白：认证关闭"); wrapMode:Text.WordWrap }
                }
            }
        }
    }
}
