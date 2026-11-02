pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    id:root
    property var vehicle:QGroundControl.multiVehicleManager.activeVehicle
    property string selectedName:""
    property bool selectedDirectory:false
    property string folder:"/"
    readonly property bool writable:vehicle && vehicle===ftp.targetVehicle && !vehicle.armed && !vehicle.flying && folder.indexOf("/@")!==0 && !ftp.busy
    property var rows:ftp.directoryEntries.map(function(entry){const type=entry.charAt(0),fields=entry.substring(1).split("\t");return {name:fields[0],directory:type==="D",size:fields[1]||"--",type:type}}).filter(function(row){return row.type!=="S"&&row.name!=="."&&row.name!==".."&&row.name.indexOf("/")<0&&row.name.indexOf("\\")<0})
    Rectangle { anchors.fill:parent; color:"#0B1E2B"; radius:ScreenTools.defaultFontPixelHeight*0.65; border.color:"#294B5D" }
    QGCPalette { id:pal }
    implicitHeight:ScreenTools.defaultFontPixelHeight*32
    FTPController { id:ftp }
    FactPanelController { id:parameters }
    property var scripting:parameters.parameterExists(-1,"SCR_ENABLE")?parameters.getParameterFact(-1,"SCR_ENABLE",false):null
    property var disabledDirs:parameters.parameterExists(-1,"SCR_DIR_DISABLE")?parameters.getParameterFact(-1,"SCR_DIR_DISABLE",false):null
    function path(name){return folder.replace(/\/+$/,"")+"/"+name}
    function refresh(){selectedName="";ftp.listDirectory(folder)}
    function go(where){if(ftp.busy)return;folder=where;refresh()}
    function confirm(title,text,callback){const target=ftp.targetVehicle;QGroundControl.showMessageDialog(root,title,text,Dialog.Yes|Dialog.No,function(){if(target&&target===QGroundControl.multiVehicleManager.activeVehicle&&!target.armed&&!target.flying)callback()})}
    Component.onCompleted: if(vehicle)refresh()
    Connections {
        target:ftp
        function onUploadComplete(file,error){if(!error)root.refresh()}
        function onDeleteComplete(file,error){if(!error){root.refresh();QGroundControl.showMessageDialog(root,qsTr("文件已删除"),qsTr("已删除 %1，无法自动撤销；仅可从已有备份恢复。").arg(file),Dialog.Ok)}}
        function onMetadataComplete(file,error){if(!error)root.refresh()}
    }
    QGCFileDialog {
        id:uploadDialog
        title:qsTr("选择上传文件（确认后写入飞控）")
        folder:QGroundControl.settingsManager.appSettings.savePath.value
        onAcceptedForLoad:function(file){const name=file.replace(/\\/g,"/").split("/").pop(),destination=root.path(name);root.confirm(qsTr("确认上传"),qsTr("将 %1 上传到 %2。若已有同名文件可能被覆盖，请先下载备份；不会自动启用脚本。").arg(name).arg(destination),function(){ftp.uploadFile(file,destination)})}
    }
    Dialog {
        id:nameDialog
        property bool rename:false
        title:rename?qsTr("重命名"):qsTr("新建文件夹")
        standardButtons:Dialog.Ok|Dialog.Cancel
        anchors.centerIn:parent
        contentItem:QGCTextField { id:nameInput; placeholderText:qsTr("字母、数字、点、下划线或短横线") }
        onAccepted:{const name=nameInput.text.trim();if(!/^[A-Za-z0-9_.-]{1,64}$/.test(name)||name==="."||name===".."||root.rows.some(function(row){return row.name.toLowerCase()===name.toLowerCase()}))return;const from=root.path(root.selectedName),to=root.path(name),renaming=rename;root.confirm(qsTr("确认修改存储卡"),qsTr("在 %1 号机执行 %2 → %3。请先保留备份。").arg(root.vehicle?root.vehicle.id:"--").arg(renaming?from:root.folder).arg(to),function(){if(renaming)ftp.renameEntry(from,to);else ftp.createDirectory(to)})}
    }
    QGCFlickable {
        anchors.fill:parent
        anchors.margins:ScreenTools.defaultFontPixelHeight*0.75
        contentWidth:width
        contentHeight:body.implicitHeight
        ColumnLayout {
            id:body
            width:parent.width
            spacing:ScreenTools.defaultFontPixelHeight*0.65
            Rectangle {
                Layout.fillWidth:true
                implicitHeight:hero.implicitHeight+ScreenTools.defaultFontPixelHeight*1.2
                radius:ScreenTools.defaultFontPixelHeight*0.6; border.color:"#335C70"
                gradient:Gradient { orientation:Gradient.Horizontal; GradientStop { position:0;color:"#193C50" } GradientStop { position:1;color:"#102A39" } }
                ColumnLayout {
                    id:hero; anchors.fill:parent; anchors.margins:ScreenTools.defaultFontPixelHeight*0.6
                    QGCLabel { Layout.fillWidth:true; text:qsTr("存储卡与 LUA · %1 号机").arg(root.vehicle?root.vehicle.id:"--"); color:"#E4F3F9"; font.family:ScreenTools.hqUiFontFamily; font.bold:true; font.pointSize:ScreenTools.mediumFontPointSize }
                    QGCLabel { Layout.fillWidth:true; wrapMode:Text.WordWrap; color:root.writable?"#75DBC9":"#FFBE79"; text:root.writable?qsTr("文件维护  /  地面未解锁 · 修改需确认"):qsTr("只读保护  /  解锁、飞行或切换主调试后不可修改") }
                }
            }
            QGCLabel { Layout.fillWidth:true; wrapMode:Text.WordWrap; color:"#9EBFCF"; text:qsTr("通过飞控真实 MAVLink FTP 维护文件。@ROMFS、@SYS 为只读区域；上传前先备份同名文件。") }
            Flow {
                Layout.fillWidth:true
                spacing:ScreenTools.defaultFontPixelWidth
                visible:!!root.scripting
                QGCCheckBox { text:qsTr("启用 LUA 脚本"); checked:root.scripting&&Number(root.scripting.rawValue)!==0; enabled:root.writable; onClicked:{const value=checked?1:0;root.confirm(qsTr("确认脚本运行设置"),qsTr("脚本可改变飞控行为。请确认脚本来源和内容可信；此设置可能需要重启生效。"),function(){root.scripting.rawValue=value})} }
                QGCCheckBox { text:qsTr("禁用 ROMFS 脚本"); checked:root.disabledDirs&&(Number(root.disabledDirs.rawValue)&1)!==0; enabled:root.writable&&!!root.disabledDirs; onClicked:{const value=checked;root.confirm(qsTr("确认脚本目录"),qsTr("修改 ROMFS 脚本目录开关，不改变其他选项位。"),function(){root.disabledDirs.rawValue=value?Number(root.disabledDirs.rawValue)|1:Number(root.disabledDirs.rawValue)&~1})} }
                QGCCheckBox { text:qsTr("禁用 APM/scripts"); checked:root.disabledDirs&&(Number(root.disabledDirs.rawValue)&2)!==0; enabled:root.writable&&!!root.disabledDirs; onClicked:{const value=checked;root.confirm(qsTr("确认脚本目录"),qsTr("修改存储卡脚本目录开关，不改变其他选项位。"),function(){root.disabledDirs.rawValue=value?Number(root.disabledDirs.rawValue)|2:Number(root.disabledDirs.rawValue)&~2})} }
            }
            Flow {
                Layout.fillWidth:true
                spacing:ScreenTools.defaultFontPixelWidth
                QGCButton { text:qsTr("根目录"); enabled:!ftp.busy; onClicked:root.go("/") }
                QGCButton { text:qsTr("脚本"); enabled:!ftp.busy; onClicked:root.go("/APM/scripts") }
                QGCButton { text:qsTr("日志"); enabled:!ftp.busy; onClicked:root.go("/APM/LOGS") }
                QGCButton { text:qsTr("上一级"); enabled:!ftp.busy&&root.folder!=="/"; onClicked:root.go(root.folder.substring(0,root.folder.lastIndexOf("/"))||"/") }
                QGCButton { text:qsTr("刷新"); enabled:!ftp.busy; onClicked:root.refresh() }
            }
            QGCLabel { Layout.fillWidth:true; text:qsTr("当前位置   %1").arg(root.folder); color:"#65D9D1"; font.bold:true; wrapMode:Text.WrapAnywhere }
            RowLayout { Layout.fillWidth:true; QGCLabel { Layout.fillWidth:true; color:"#8EB0C2"; text:qsTr("名称"); font.bold:true } QGCLabel { Layout.preferredWidth:ScreenTools.defaultFontPixelWidth*12; color:"#8EB0C2"; text:qsTr("大小"); font.bold:true } QGCLabel { Layout.preferredWidth:ScreenTools.defaultFontPixelWidth*10; color:"#8EB0C2"; text:qsTr("类型"); font.bold:true } }
            Repeater {
                model:root.rows
                QGCButton {
                    id:fileRow
                    required property var modelData
                    Layout.fillWidth:true
                    text:modelData.name
                    implicitHeight:ScreenTools.defaultFontPixelHeight*2.5
                    checked:root.selectedName===modelData.name
                    background:Rectangle { radius:ScreenTools.defaultFontPixelHeight*0.4; color:fileRow.checked?"#215264":fileRow.hovered?"#193B4E":"#122E40"; border.color:fileRow.checked?"#65D9D1":"#264D62" }
                    contentItem:RowLayout {
                        QGCLabel { Layout.fillWidth:true; color:"#E3F2F8"; text:fileRow.modelData.name; elide:Text.ElideMiddle; font.family:ScreenTools.hqUiFontFamily }
                        QGCLabel { Layout.preferredWidth:ScreenTools.defaultFontPixelWidth*12; color:"#9DBDCC"; text:fileRow.modelData.directory?"--":fileRow.modelData.size+" B" }
                        QGCLabel { Layout.preferredWidth:ScreenTools.defaultFontPixelWidth*10; color:fileRow.modelData.directory?"#FFCA82":"#78E1CF"; text:fileRow.modelData.directory?qsTr("文件夹"):fileRow.modelData.name.toLowerCase().endsWith(".lua")?qsTr("LUA 脚本"):qsTr("文件") }
                    }
                    onClicked:{root.selectedName=modelData.name;root.selectedDirectory=modelData.directory}
                    onDoubleClicked:if(modelData.directory)root.go(root.path(modelData.name))
                }
            }
            QGCLabel { Layout.fillWidth:true; visible:!root.rows.length&&!ftp.busy; text:ftp.errorString?ftp.errorString:qsTr("目录为空，或飞控尚未返回列表。") }
            Flow {
                Layout.fillWidth:true
                spacing:ScreenTools.defaultFontPixelWidth
                QGCButton { text:qsTr("打开文件夹"); enabled:root.selectedDirectory&&root.selectedName&&!ftp.busy; onClicked:root.go(root.path(root.selectedName)) }
                QGCButton { text:qsTr("下载选中文件"); enabled:root.selectedName&&!root.selectedDirectory&&!ftp.busy; onClicked:ftp.downloadFile(root.path(root.selectedName),downloadDirectory.text) }
                QGCButton { text:qsTr("上传"); enabled:root.writable; onClicked:uploadDialog.openForLoad() }
                QGCButton { text:qsTr("新建文件夹"); enabled:root.writable; onClicked:{nameDialog.rename=false;nameInput.text="";nameDialog.open()} }
                QGCButton { text:qsTr("重命名"); enabled:root.writable&&root.selectedName; onClicked:{nameDialog.rename=true;nameInput.text=root.selectedName;nameDialog.open()} }
                QGCButton { text:qsTr("删除文件"); enabled:root.writable&&root.selectedName&&!root.selectedDirectory; onClicked:{const file=root.path(root.selectedName);root.confirm(qsTr("确认删除"),qsTr("永久删除 %1，无法自动撤销。请确认已下载备份。").arg(file),function(){ftp.deleteFile(file)})} }
            }
            QGCLabel { color:"#8EB0C2"; text:qsTr("本地下载目录") }
            QGCTextField { id:downloadDirectory; Layout.fillWidth:true; text:QGroundControl.settingsManager.appSettings.savePath.value+"/StorageDownloads" }
            QGCLabel { Layout.fillWidth:true; wrapMode:Text.WordWrap; text:ftp.lastDownloadFile?qsTr("已下载：%1").arg(ftp.lastDownloadFile):ftp.errorString; color:pal.warningText }
            ProgressBar { Layout.fillWidth:true; visible:ftp.busy; indeterminate:ftp.listInProgress; value:ftp.progress }
            QGCButton { text:qsTr("取消当前操作"); visible:ftp.busy; onClicked:ftp.cancelActiveOperation() }
        }
    }
}
