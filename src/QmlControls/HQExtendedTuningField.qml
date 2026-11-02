pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    required property var tuningModel
    required property var spec
    property real textScale: 1
    property bool sectionEnabled: true
    readonly property var fact: tuningModel.parameterFact(spec.names)
    readonly property bool available: !!fact
    readonly property bool changed: available && tuningModel.isChanged(fact)
    readonly property string inputText: tuningModel.textFor(fact)
    readonly property string error: changed ? tuningModel.errorFor(fact, inputText) : ""
    readonly property var enums: fact && fact.enumStrings ? fact.enumStrings : []
    readonly property var masks: fact && fact.bitmaskStrings ? fact.bitmaskStrings : []
    readonly property bool enumField: enums.length > 0 && masks.length === 0
    readonly property bool narrow: width < 480
    readonly property bool stacked: width < 340
    readonly property real namePixelSize: Math.max(13, ScreenTools.defaultFontPixelHeight * 0.74 * textScale)
    implicitHeight: available ? fieldColumn.implicitHeight : 0
    visible: available
    objectName: fact ? "extendedField-" + fact.name : "extendedFieldUnavailable"

    QGCPalette {
        id: fieldPalette
        colorGroupEnabled: root.enabled && root.sectionEnabled && root.available && !root.fact.readOnly
    }

    function increment(direction) {
        if (!fact || fact.readOnly) return
        const decimals = Math.max(0, Math.min(8, Number(fact.decimalPlaces)))
        let step = Number(fact.increment)
        if (!isFinite(step) || step <= 0) step = Math.pow(10, -decimals)
        let value = Number(inputText)
        if (!isFinite(value)) value = Number(fact.value)
        value += direction * step
        if (isFinite(Number(fact.min))) value = Math.max(Number(fact.min), value)
        if (isFinite(Number(fact.max))) value = Math.min(Number(fact.max), value)
        tuningModel.stage(fact, value.toFixed(decimals))
    }
    function toggleMask(index, selected) {
        const bit = Number(fact.bitmaskValues[index])
        const value = Number(inputText) || 0
        tuningModel.stage(fact, String((selected ? value | bit : value & ~bit) >>> 0))
    }
    ColumnLayout {
        id: fieldColumn
        width: parent.width
        spacing: 3
        GridLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            columns: root.stacked ? 1 : root.narrow ? 2 : 3
            columnSpacing: 10
            rowSpacing: 4
            QGCLabel {
                Layout.preferredWidth: root.stacked ? root.width : root.width * (root.narrow ? 0.33 : 0.24)
                Layout.fillWidth: root.stacked
                text: root.spec.label
                color: "#D4E1E9"
                wrapMode: Text.WordWrap
                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.80 * root.textScale
            }
            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: root.stacked ? 0 : 140
                Layout.preferredHeight: Math.max(44, ScreenTools.minTouchPixels)
                enabled: root.sectionEnabled && root.available && !root.fact.readOnly
                opacity: enabled ? 1 : 0.55
                RowLayout {
                    anchors.fill: parent
                    spacing: 3
                    QGCButton {
                        visible: !root.enumField && root.masks.length === 0
                        text: "−"
                        Layout.preferredWidth: ScreenTools.isMobile ? 44 : 30
                        Layout.maximumWidth: Layout.preferredWidth
                        Layout.fillHeight: true
                        leftPadding: 0; rightPadding: 0
                        Accessible.name: root.spec.label + " −"
                        onClicked: root.increment(-1)
                    }
                    QGCTextField {
                        objectName: "extendedNumericInput"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 55
                        visible: !root.enumField
                        text: root.inputText
                        numericValuesOnly: true
                        unitsLabel: root.fact ? root.fact.units : ""
                        showUnits: true
                        color: root.error ? (fieldPalette.globalTheme === QGCPalette.Dark ? "#FFB4BE" : "#A31535")
                            : root.changed ? (fieldPalette.globalTheme === QGCPalette.Dark ? "#FFD28A" : "#775000")
                            : fieldPalette.textFieldText
                        font.pixelSize: root.namePixelSize + 1
                        Accessible.name: root.spec.label
                        onTextEdited: root.tuningModel.stage(root.fact, text)
                    }
                    QGCComboBox {
                        objectName: "extendedEnumInput"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.enumField
                        model: root.enums
                        alternateText: currentIndex < 0 ? root.inputText + (root.fact && root.fact.units ? " " + root.fact.units : "") : ""
                        currentIndex: root.fact && root.fact.enumValues ? root.fact.enumValues.map(Number).indexOf(Number(root.inputText)) : -1
                        onActivated: index => root.tuningModel.stage(root.fact, String(root.fact.enumValues[index]))
                    }
                    QGCButton {
                        visible: !root.enumField && root.masks.length === 0
                        text: "+"
                        Layout.preferredWidth: ScreenTools.isMobile ? 44 : 30
                        Layout.maximumWidth: Layout.preferredWidth
                        Layout.fillHeight: true
                        leftPadding: 0; rightPadding: 0
                        Accessible.name: root.spec.label + " +"
                        onClicked: root.increment(1)
                    }
                    QGCButton {
                        visible: root.masks.length > 0
                        text: "⋯"
                        Layout.preferredWidth: 44
                        Layout.maximumWidth: 44
                        Layout.fillHeight: true
                        leftPadding: 0; rightPadding: 0
                        Accessible.name: qsTr("Choose flags")
                        onClicked: flagPopup.open()
                    }
                }
            }
            QGCLabel {
                objectName: "extendedParameterName"
                Layout.minimumWidth: 0
                Layout.columnSpan: root.stacked ? 1 : root.narrow ? 2 : 1
                Layout.fillWidth: true
                Layout.preferredWidth: root.narrow ? root.width : Math.max(155, root.width * 0.32)
                text: root.fact ? root.fact.name : ""
                color: "#AECBD9"
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: root.namePixelSize
                wrapMode: Text.WrapAnywhere
            }
        }
        QGCLabel {
            Layout.fillWidth: true
            visible: root.error.length > 0
            text: root.error
            color: "#FF9A87"
            wrapMode: Text.WordWrap
            font.pixelSize: root.namePixelSize
        }
    }
    Popup {
        id: flagPopup
        parent: Overlay.overlay
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0
        width: parent ? Math.min(parent.width - 24, 430) : 400
        height: parent ? Math.min(parent.height - 24, flagColumn.implicitHeight + padding * 2) : 400
        modal: true
        focus: true
        padding: 14
        background: Rectangle { radius: 8; color: "#102A3E"; border.color: "#426578" }
        contentItem: Flickable {
            clip: true
            contentHeight: flagColumn.implicitHeight
            ColumnLayout {
                id: flagColumn
                width: parent.width
                QGCLabel { Layout.fillWidth: true; text: root.spec.label; color: "white"; wrapMode: Text.WordWrap }
                Repeater {
                    model: root.masks
                    QGCCheckBox {
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        text: modelData
                        checked: root.fact ? (Number(root.inputText) & Number(root.fact.bitmaskValues[index])) !== 0 : false
                        onClicked: root.toggleMask(index, checked)
                    }
                }
                QGCButton { text: qsTr("Done"); onClicked: flagPopup.close() }
            }
        }
    }
}
