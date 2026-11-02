import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Item {
    id:         _root

    property Fact   _editorDialogFact: Fact { }
    property int    _rowHeight:         ScreenTools.defaultFontPixelHeight * 2
    property int    _rowWidth:          10 // Dynamic adjusted at runtime
    property bool   _searchFilter:      searchText.text.trim() != "" || controller.showModifiedOnly || controller.showFavoritesOnly  ///< true: showing results of search
    property var    _searchResults      ///< List of parameter names from search results
    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _showRCToParam:     !!_activeVehicle && _activeVehicle.px4Firmware
    property var    _appSettings:       QGroundControl.settingsManager.appSettings
    property var    _controller:        controller
    property var    _favorites:         controller.favoriteParameterNames
    property real   _margins:           ScreenTools.defaultFontPixelHeight / 2
    property bool   _showOriginalDescriptions: false
    readonly property bool handlesPageMotion: true
    property bool animationsEnabled: QGroundControl.loadBoolGlobalSetting("HQParameterTable/Animations", true)
    transform: [
        Translate { x: pageMotion.offset },
        Rotation { origin.x: 0; origin.y: _root.height / 2; axis: Qt.vector3d(0, 1, 0); angle: pageMotion.angle },
        Scale { origin.x: 0; origin.y: _root.height / 2; xScale: pageMotion.surfaceScale; yScale: pageMotion.surfaceScale }
    ]
    HQParameterMotion {
        id: pageMotion
        objectName: "parameterPageMotion"
        targetItem: _root
        animationsEnabled: _root.animationsEnabled
        foldDegrees: -7
        travel: 16
        duration: 300
    }
    Component.onCompleted: Qt.callLater(pageMotion.reveal)

    ParameterEditorController {
        id: controller
    }

    Timer {
        id:         clearTimer
        interval:   100;
        running:    false;
        repeat:     false
        onTriggered: {
            searchText.text = ""
            controller.searchText = ""
        }
    }

    QGCMenu {
        id:                 toolsMenu
        QGCMenuItem {
            text: qsTr("Parameter table animations")
            checkable: true
            checked: _root.animationsEnabled
            onTriggered: {
                _root.animationsEnabled = checked
                QGroundControl.saveBoolGlobalSetting("HQParameterTable/Animations", checked)
            }
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            text:           qsTr("Refresh")
            onTriggered:	controller.refresh()
        }
        QGCMenuItem {
            text:           qsTr("Reset all to firmware's defaults")
            onTriggered:    QGroundControl.showMessageDialog(_root, qsTr("Reset All"),
                                                         qsTr("Select Reset to reset all parameters to their defaults.\n\nNote that this will also completely reset everything, including UAVCAN nodes, all vehicle settings, setup and calibrations."),
                                                         Dialog.Cancel | Dialog.Reset,
                                                         function() { controller.resetAllToDefaults() })
        }
        QGCMenuItem {
            text:           qsTr("Reset to vehicle's configuration defaults")
            visible:        !!_activeVehicle && !_activeVehicle.apmFirmware
            onTriggered:    QGroundControl.showMessageDialog(_root, qsTr("Reset All"),
                                                         qsTr("Select Reset to reset all parameters to the vehicle's configuration defaults."),
                                                         Dialog.Cancel | Dialog.Reset,
                                                         function() { controller.resetAllToVehicleConfiguration() })
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            objectName:     "parameterEditor_toolLoadFromFile"
            text:           qsTr("Load from file for review...")
            onTriggered: {
                fileDialog.title =          qsTr("Load Parameters")
                fileDialog.openForLoad()
            }
        }
        QGCMenuItem {
            text:           qsTr("Save to file...")
            onTriggered: {
                fileDialog.title =          qsTr("Save Parameters")
                fileDialog.openForSave()
            }
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            text:           qsTr("Clear all favorites")
            onTriggered:    controller.clearAllFavorites()
        }
        QGCMenuSeparator { visible: _showRCToParam }
        QGCMenuItem {
            text:           qsTr("Clear all RC to Param")
            onTriggered:	_activeVehicle.clearAllParamMapRC()
            visible:        _showRCToParam
        }
        QGCMenuSeparator { }
        QGCMenuItem {
            text:           qsTr("Reboot Vehicle")
            onTriggered:    QGroundControl.showMessageDialog(_root, qsTr("Reboot Vehicle"),
                                                         qsTr("Select Ok to reboot vehicle."),
                                                         Dialog.Cancel | Dialog.Ok,
                                                         function() { _activeVehicle.rebootVehicle() })
        }
    }


    QGCFileDialog {
        id:             fileDialog
        folder:         _appSettings.parameterSavePath
        nameFilters:    [ qsTr("Parameter Files (*.%1)").arg(_appSettings.parameterFileExtension), qsTr("Mission Planner Files (*.param)"), qsTr("All Files (*)") ]

        onAcceptedForSave: (file) => {
            controller.saveToFile(file)
            close()
        }

        onAcceptedForLoad: (file) => {
            close()
            if (controller.buildDiffFromFile(file)) {
                parameterDiffDialogFactory.open()
            }
        }
    }

    QGCPopupDialogFactory {
        id: editorDialogFactory

        dialogComponent: editorDialogComponent
    }

    Component {
        id: editorDialogComponent

        ParameterEditorDialog {
            fact:           _editorDialogFact
            showRCToParam:  _showRCToParam
            showOriginalDescriptions: _showOriginalDescriptions
            animationsEnabled: _root.animationsEnabled
        }
    }

    QGCPopupDialogFactory {
        id: parameterDiffDialogFactory

        dialogComponent: parameterDiffDialog
    }

    Component {
        id: parameterDiffDialog

        ParameterDiffDialog {
            paramController: _controller
        }
    }

    QGCPopupDialogFactory {
        id: peripheralSetupDialogFactory
        dialogComponent: peripheralSetupDialogComponent
    }

    Component {
        id: peripheralSetupDialogComponent

        PeripheralSetupDialog {
            controller: _controller
            vehicle: _activeVehicle
        }
    }

    RowLayout {
        id:             header
        anchors.left:   parent.left
        anchors.right:  parent.right

        RowLayout {
            Layout.alignment:   Qt.AlignLeft
            spacing:            ScreenTools.defaultFontPixelWidth

            QGCTextField {
                id:                     searchText
                placeholderText:        qsTr("Search")
                onDisplayTextChanged:   controller.searchText = displayText
            }

            QGCButton {
                text: qsTr("Clear")
                onClicked: {
                    if(ScreenTools.isMobile) {
                        Qt.inputMethod.hide();
                    }
                    clearTimer.start()
                }
            }

            QGCCheckBox {
                text:       qsTr("Hide read-only")
                checked:    controller.hideReadOnly
                onClicked:  controller.hideReadOnly = checked
            }

            QGCComboBox {
                visible: _activeVehicle && _activeVehicle.apmFirmware
                model: [qsTr("中文注释"), qsTr("English Original")]
                currentIndex: _root._showOriginalDescriptions ? 1 : 0
                onActivated: index => _root._showOriginalDescriptions = index === 1
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight

            QGCButton {
                text: qsTr("外设配置建议")
                enabled: !!_activeVehicle
                onClicked: peripheralSetupDialogFactory.open()
            }

            QGCButton {
                objectName:         "parameterEditor_toolsButton"
                text:               qsTr("Tools")
                onClicked:          toolsMenu.popup()
            }
        }
    }

    QGCTabBar {
        id:             tabBar
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.top:        header.bottom
        anchors.topMargin:  _margins

        QGCTabButton { text: qsTr("Full List") }
        QGCTabButton { text: qsTr("Modified") }
        QGCTabButton { text: qsTr("Favorites") }

        onCurrentIndexChanged: {
            controller.showModifiedOnly  = (currentIndex === 1)
            controller.showFavoritesOnly = (currentIndex === 2)
            dataReveal.restart()
        }
    }

    /// Group buttons
    QGCFlickable {
        id :                groupScroll
        width:              ScreenTools.defaultFontPixelWidth * 25
        anchors.top:        tabBar.bottom
        anchors.topMargin:  _margins
        anchors.bottom:     parent.bottom
        clip:               true
        pixelAligned:       true
        contentHeight:      groupedViewCategoryColumn.height
        flickableDirection: Flickable.VerticalFlick
        visible:            !_searchFilter

        ColumnLayout {
            id:             groupedViewCategoryColumn
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        Math.ceil(ScreenTools.defaultFontPixelHeight * 0.25)

            Repeater {
                model: controller.categories

                HQParameterGroup {
                    required property var object
                    Layout.fillWidth:   true
                    title: object.name
                    expanded: object == controller.currentCategory
                    groupModel: object.groups
                    animationsEnabled: _root.animationsEnabled
                    onToggleRequested: controller.currentCategory = expanded ? null : object
                    groupDelegate: Component {
                        QGCButton {
                            required property var object
                            width:          parent.width
                            text:           object.name
                            height:         _rowHeight
                            checked:        object == controller.currentGroup
                            autoExclusive:  true

                            onClicked: {
                                if (!checked) _rowWidth = 10
                                checked = true
                                controller.currentGroup = object
                                dataReveal.restart()
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: parameterCard
        objectName: "parameterDataCard"
        anchors.top: tabBar.bottom
        anchors.topMargin: _margins
        anchors.bottom: parent.bottom
        anchors.left: _searchFilter ? parent.left : groupScroll.right
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
        anchors.right: parent.right
        clip: true
        transform: [
            Translate { x: dataMotion.offset },
            Scale { origin.x: 0; origin.y: 0; xScale: dataMotion.surfaceScale; yScale: dataMotion.surfaceScale }
        ]
        HQParameterMotion { id: dataMotion; objectName: "parameterDataMotion"; targetItem: parameterCard; animationsEnabled: _root.animationsEnabled }
        // Coalesce model resets and rapid clicks into one visual reveal.
        Timer { id: dataReveal; interval: 0; onTriggered: dataMotion.reveal() }
        Connections {
            target: controller.parameters
            ignoreUnknownSignals: true
            function onModelReset() { dataReveal.restart() }
        }
        Connections {
            target: controller
            function onParametersChanged() { dataReveal.restart() }
        }

        HorizontalHeaderView {
            id:                 headerView
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        parent.top
            syncView:           tableView
            clip:               true

            delegate: Rectangle {
                implicitWidth:  column === 0 ? ScreenTools.implicitCheckBoxHeight + ScreenTools.defaultFontPixelWidth
                                             : headerLabel.contentWidth + ScreenTools.defaultFontPixelWidth
                implicitHeight: headerLabel.contentHeight + ScreenTools.defaultFontPixelHeight * 0.5
                color:          qgcPal.windowShade

                QGCLabel {
                    id:                     headerLabel
                    anchors.left:           parent.left
                    anchors.leftMargin:     ScreenTools.defaultFontPixelWidth / 2
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   display
                    font.bold:              true
                }

                // Top border
                Rectangle {
                    anchors.top:    parent.top
                    width:          parent.width
                    height:         1
                    color:          qgcPal.groupBorder
                }

                // Left border
                Rectangle {
                    anchors.left:   parent.left
                    height:         parent.height
                    width:          1
                    color:          qgcPal.groupBorder
                }

                // Right border (last column only)
                Rectangle {
                    anchors.right:  parent.right
                    height:         parent.height
                    width:          1
                    color:          qgcPal.groupBorder
                    visible:        column == 3
                }

                // Bottom border
                Rectangle {
                    anchors.bottom: parent.bottom
                    width:          parent.width
                    height:         1
                    color:          qgcPal.groupBorder
                }
            }
        }

        TableView {
            id:                 tableView
            anchors.top:        headerView.bottom
            anchors.bottom:     parent.bottom
            anchors.left:       parent.left
            anchors.right:      parent.right
            columnSpacing:      0
            rowSpacing:         0
            model:              controller.parameters
            contentWidth:       width
            clip:               true

            // Qt is supposed to adjust column widths automatically when larger widths come into view.
            // But it doesn't work. So we have to do it force a layout manually when we scroll.
            Timer {
                id:             forceLayoutTimer
                interval:       500
                repeat:         false
                onTriggered:    tableView.forceLayout()
            }

            onTopRowChanged: forceLayoutTimer.start()
            onModelChanged: {
                dataReveal.restart()
                positionViewAtRow(0, TableView.AlignLeft | TableView.AlignTop)
                forceLayoutTimer.start()
            }

            delegate: Rectangle {
                implicitWidth:  column === 0 ? ScreenTools.implicitCheckBoxHeight + ScreenTools.defaultFontPixelWidth
                                             : column === 1 ? nameRow.implicitWidth + ScreenTools.defaultFontPixelWidth
                                             : column === 2 ? ScreenTools.defaultFontPixelWidth * 16
                                                            : label.contentWidth + ScreenTools.defaultFontPixelWidth
                implicitHeight: label.contentHeight + ScreenTools.defaultFontPixelHeight * 0.5
                color:          row % 2 === 0 ? "transparent" : qgcPal.windowShade
                clip:           true

                // Bottom grid line
                Rectangle {
                    anchors.bottom: parent.bottom
                    width:          parent.width
                    height:         1
                    color:          qgcPal.groupBorder
                }

                // Left grid line
                Rectangle {
                    anchors.left:   parent.left
                    height:         parent.height
                    width:          1
                    color:          qgcPal.groupBorder
                }

                // Right grid line (last column only)
                Rectangle {
                    anchors.right:  parent.right
                    height:         parent.height
                    width:          1
                    color:          qgcPal.groupBorder
                    visible:        column == 3
                }

                QGCCheckBox {
                    visible:                column === 0
                    anchors.centerIn:       parent
                    checked:                _root._favorites.indexOf(fact.name) >= 0
                    z:                      1
                    onClicked:              controller.toggleFavorite(fact.name)
                }

                Row {
                    id:                     nameRow
                    visible:                column === 1
                    anchors.left:           parent.left
                    anchors.leftMargin:     ScreenTools.defaultFontPixelWidth / 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing:               lockIcon.visible ? ScreenTools.defaultFontPixelWidth / 3 : 0

                    QGCLabel {
                        text:               column === 1 ? display : ""
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    QGCColoredImage {
                        id:                 lockIcon
                        visible:            fact.readOnly
                        source:             "qrc:/InstrumentValueIcons/lock-closed.svg"
                        color:              qgcPal.text
                        width:              ScreenTools.defaultFontPixelHeight * 0.8
                        height:             width
                        sourceSize.width:   width
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                QGCLabel {
                    id:                 label
                    visible:            column !== 0 && column !== 1
                    anchors.left:       parent.left
                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width:              column == 2 ? ScreenTools.defaultFontPixelWidth * 15 : implicitWidth
                    text:               column == 2 ? col1String()
                                        : (column == 3 && _root._showOriginalDescriptions && fact.originalShortDescription !== ""
                                           ? fact.originalShortDescription : display)
                    color:              column == 2 && fact.defaultValueAvailable && !fact.valueEqualsDefault ? qgcPal.modifiedParamValue : qgcPal.text
                    font.bold:          column == 2 && fact.defaultValueAvailable && !fact.valueEqualsDefault
                    maximumLineCount:   1
                    elide:              column == 2 ? Text.ElideRight : Text.ElideNone

                    function col1String() {
                        if (fact.enumStrings.length === 0) {
                            return fact.valueString + " " + fact.units
                        }
                        if (fact.bitmaskStrings.length != 0) {
                            return fact.selectedBitmaskStrings.join(',')
                        }
                        return fact.enumStringValue
                    }
                }

                QGCMouseArea {
                    anchors.fill: parent
                    visible:      column !== 0
                    onClicked: mouse => {
                        _editorDialogFact = fact
                        editorDialogFactory.open()
                    }
                }
            }
        }
    }
}
