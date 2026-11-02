import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

QGCPopupDialog {
    id:         root
    title:      qsTr("Select Mission Command")
    buttons:    Dialog.Cancel

    property var    vehicle
    property var    missionItem
    property var    map
    property bool   flyThroughCommandsAllowed

    ColumnLayout {
        width: Math.min(root.maxContentAvailableWidth, ScreenTools.defaultFontPixelWidth * 44)
        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth

            QGCLabel {
                text: qsTr("Category:")
            }

            QGCComboBox {
                id:                     categoryCombo
                Layout.preferredWidth:  30 * ScreenTools.defaultFontPixelWidth
                Layout.fillWidth:       true
                model:                  QGroundControl.missionCommandTree.categoriesForVehicle(vehicle)

                function categorySelected(category) {
                    commandList.model = QGroundControl.missionCommandTree.getCommandsForCategory(vehicle, category, flyThroughCommandsAllowed)
                }

                Component.onCompleted: {
                    var category  = missionItem.category
                    currentIndex = find(category)
                    categorySelected(category)
                }

                onActivated: (index) => { categorySelected(textAt(index)) }
            }
        }

        Repeater {
            id:                 commandList
            Layout.fillWidth:   true

            delegate: Rectangle {
                objectName: "missionCommand_" + mavCmdInfo.command
                width:  parent.width
                height: commandColumn.height + ScreenTools.defaultFontPixelHeight
                color:  QGroundControl.globalPalette.button
                border.width: missionItem && missionItem.command === mavCmdInfo.command ? 1 : 0
                border.color: QGroundControl.globalPalette.planWaypoint

                property var    mavCmdInfo: modelData
                property color  textColor:  QGroundControl.globalPalette.buttonText

                Column {
                    id:                 commandColumn
                    anchors.margins:    ScreenTools.defaultFontPixelWidth
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top

                    QGCLabel {
                        width:          parent.width
                        text:           mavCmdInfo.bilingualFriendlyName
                        wrapMode:       Text.WordWrap
                        color:          textColor
                        font.bold:      true
                    }

                    QGCLabel {
                        anchors.margins:    ScreenTools.defaultFontPixelWidth
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        text:               mavCmdInfo.description
                        wrapMode:           Text.WordWrap
                        color:              textColor
                    }
                }

                MouseArea {
                    anchors.fill:   parent
                    onClicked: {
                        missionItem.setMapCenterHintForCommandChange(map.center)
                        missionItem.command = mavCmdInfo.command
                        root.close()
                    }
                }
            }
        }
    }
}
