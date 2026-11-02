import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    id: root
    spacing: _rowSpacing

    property bool hasSerialPorts: false

    function refreshPortModel() {
        const portNames = QGroundControl.linkManager.serialPorts
        const portLabels = QGroundControl.linkManager.serialPortStrings
        const labels = []
        for (let i = 0; i < portNames.length; i++) {
            const label = i < portLabels.length && portLabels[i].length > 0 ? portLabels[i] : portNames[i]
            labels.push(label)
        }

        root.hasSerialPorts = portNames.length > 0
        if (!root.hasSerialPorts) {
            commPortCombo.model = [qsTr("None Available")]
            commPortCombo.currentIndex = 0
            return
        }

        let selectedIndex = portNames.indexOf(subEditConfig ? subEditConfig.portName : "")
        if (selectedIndex < 0) {
            selectedIndex = labels.findIndex(label => /mavlink/i.test(label))
            if (selectedIndex < 0) selectedIndex = 0
            if (subEditConfig) {
                subEditConfig.portName = portNames[selectedIndex]
            }
        }
        commPortCombo.model = labels
        commPortCombo.currentIndex = selectedIndex
    }

    function saveSettings() {
        if (baudCombo.isCustomBaud) {
            var baud = parseInt(customBaudField.text)
            if (baud > 0) {
                subEditConfig.baud = baud
            }
        }
    }

    GridLayout {
        columns:        2
        rowSpacing:     _rowSpacing
        columnSpacing:  _colSpacing

        QGCLabel { text: qsTr("Serial Port") }
        RowLayout {
            Layout.preferredWidth: _secondColumnWidth
            spacing:               _colSpacing

            QGCComboBox {
                id:                commPortCombo
                objectName:        "hdzxSerialPortSelector"
                Layout.fillWidth:  true
                enabled:           root.hasSerialPorts

                onActivated: (index) => {
                    const ports = QGroundControl.linkManager.serialPorts
                    if (subEditConfig && index >= 0 && index < ports.length) {
                        subEditConfig.portName = ports[index]
                    }
                }
            }

            QGCButton {
                text: qsTr("Refresh")
                onClicked: {
                    QGroundControl.linkManager.refreshSerialPorts()
                    root.refreshPortModel()
                }
            }
        }

        QGCLabel { text: qsTr("Baud Rate") }
        QGCComboBox {
            id:                     baudCombo
            Layout.preferredWidth:  _secondColumnWidth

            readonly property string _customLabel:    qsTr("Custom")
            readonly property bool   isCustomBaud:    currentText === _customLabel

            onActivated: (index) => {
                if (index !== -1 && !isCustomBaud) {
                    subEditConfig.baud = parseInt(currentText)
                }
            }

            Component.onCompleted: {
                var rates = QGroundControl.linkManager.serialBaudRates.slice()
                rates.push(_customLabel)
                model = rates

                var baud = subEditConfig ? subEditConfig.baud.toString() : "57600"
                var index = baudCombo.find(baud)
                if (index === -1) {
                    baudCombo.currentIndex = baudCombo.count - 1
                    customBaudField.text = baud
                } else {
                    baudCombo.currentIndex = index
                }
            }
        }

        QGCLabel {
            text:    qsTr("Custom Baud Rate")
            visible: baudCombo.isCustomBaud
        }
        QGCTextField {
            id:                     customBaudField
            Layout.preferredWidth:  _secondColumnWidth
            visible:                baudCombo.isCustomBaud
            numericValuesOnly:      true
            validator:              IntValidator { bottom: 1 }
            onEditingFinished: {
                if (!baudCombo.isCustomBaud) return
                var baud = parseInt(text)
                if (baud > 0) {
                    subEditConfig.baud = baud
                }
            }
        }
    }

    QGCCheckBox {
        id:         advancedSettings
        text:       qsTr("Advanced Settings")
        checked:    false
    }

    GridLayout {
        columns:        2
        rowSpacing:     _rowSpacing
        columnSpacing:  _colSpacing
        visible:        advancedSettings.checked

        QGCCheckBox {
            Layout.columnSpan:  2
            text:               qsTr("Enable Flow Control")
            checked:            subEditConfig.flowControl !== 0
            onCheckedChanged:   subEditConfig.flowControl = checked ? 1 : 0
        }

        QGCCheckBox {
            Layout.columnSpan:  2
            text:               qsTr("Force DTR Low")
            checked:            subEditConfig ? subEditConfig.dtrForceLow : false
            onCheckedChanged:   { if (subEditConfig) subEditConfig.dtrForceLow = checked }
        }

        QGCLabel { text: qsTr("Parity") }
        QGCComboBox {
            Layout.preferredWidth:  _secondColumnWidth
            model:                  [qsTr("None"), qsTr("Even"), qsTr("Odd")]

            onActivated: (index) => {
                // Hard coded values from qserialport.h
                switch (index) {
                case 0:
                    subEditConfig.parity = 0
                    break
                case 1:
                    subEditConfig.parity = 2
                    break
                case 2:
                    subEditConfig.parity = 3
                    break
                }
            }

            Component.onCompleted: {
                switch (subEditConfig.parity) {
                case 0:
                    currentIndex = 0
                    break
                case 2:
                    currentIndex = 1
                    break
                case 3:
                    currentIndex = 2
                    break
                default:
                    console.warn("Unknown parity", subEditConfig.parity)
                    break
                }
            }
        }

        QGCLabel { text: qsTr("Data Bits") }
        QGCComboBox {
            Layout.preferredWidth:  _secondColumnWidth
            model:                  [ "5", "6", "7", "8" ]
            currentIndex:           Math.max(Math.min(subEditConfig.dataBits - 5, 3), 0)
            onActivated: (index) => { subEditConfig.dataBits = index + 5 }
        }

        QGCLabel { text: qsTr("Stop Bits") }
        QGCComboBox {
            Layout.preferredWidth:  _secondColumnWidth
            model:                  [ "1", "2" ]
            currentIndex:           Math.max(Math.min(subEditConfig.stopBits - 1, 1), 0)
            onActivated: (index) => { subEditConfig.stopBits = index + 1 }
        }
    }

    Connections {
        target: QGroundControl.linkManager
        function onCommPortsChanged() { root.refreshPortModel() }
        function onCommPortStringsChanged() { root.refreshPortModel() }
    }

    Component.onCompleted: {
        QGroundControl.linkManager.refreshSerialPorts()
        refreshPortModel()
    }
}
