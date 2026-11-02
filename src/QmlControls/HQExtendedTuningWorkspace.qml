pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import "HQExtendedTuningParameters.js" as ParameterCatalog

Item {
    id: root
    property alias model: parameterModel
    property alias vehicle: parameterModel.vehicle
    property bool showHeading: true
    property real textScale: 1
    readonly property var sections: ParameterCatalog.sections()
    HQExtendedTuningModel { id: parameterModel }

    function specsFor(section) {
        const revision = parameterModel.parameterRevision
        return section.params.filter(function(spec) { return !!parameterModel.parameterFact(spec.names) })
    }
    function sectionVisible(section) {
        if (!parameterModel.vehicle) return false
        if ((section.firmware === "px4") !== parameterModel.isPX4) return false
        return section.key !== "apm-harmonic-notch-2" || specsFor(section).length > 0
    }
    function sectionHint(section, count) {
        if (!parameterModel.parametersReady) return qsTr("Waiting for flight-controller parameters…")
        if (section.gate) {
            const gate = parameterModel.parameterFact(section.gate)
            if (!gate) return section.staticLegacy ? section.hint : qsTr("This firmware has not reported this feature's parameters.")
            if (Number(gate.rawValue) === 0) return section.hint || qsTr("Enable and submit this feature, then reboot and reload parameters for its settings.")
            if (count <= 1) return qsTr("Enabled, but detailed parameters are not available yet. Reconnect or reload parameters; firmware builds may omit this feature.")
        }
        if (!count) return qsTr("No matching parameters reported. Check the vehicle type, firmware version and parameter download.")
        return section.hint || ""
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        QGCLabel {
            visible: root.showHeading
            text: qsTr("Extended tuning") + (parameterModel.vehicle ? (parameterModel.isPX4 ? " · PX4" : " · ArduPilot") : "")
            font.pointSize: ScreenTools.mediumFontPointSize
            font.bold: true
            color: "#DCE9F1"
        }
        QGCLabel {
            Layout.fillWidth: true
            text: qsTr("Values and units follow the connected firmware. Changes stay local until you confirm submission; only disarmed vehicles can receive them.")
            color: "#A9C3D3"
            wrapMode: Text.WordWrap
            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.76 * root.textScale
        }
        QGCLabel {
            visible: !parameterModel.vehicle
            Layout.fillWidth: true
            text: qsTr("Connect a flight controller to load its available tuning parameters.")
            color: "#E9B36A"
            wrapMode: Text.WordWrap
        }
        Flickable {
            id: scroll
            objectName: "extendedTuningScroll"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: sectionGrid.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }
            GridLayout {
                id: sectionGrid
                width: scroll.width
                columns: width >= 1120 ? 2 : 1
                columnSpacing: 12
                rowSpacing: 12
                Repeater {
                    model: root.sections
                    Rectangle {
                        id: section
                        required property var modelData
                        readonly property var specs: root.specsFor(modelData)
                        readonly property var gate: modelData.gate ? parameterModel.parameterFact(modelData.gate) : null
                        readonly property string hint: root.sectionHint(modelData, specs.length)
                        objectName: "extendedSection-" + modelData.key
                        visible: root.sectionVisible(modelData)
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignTop
                        implicitHeight: sectionColumn.implicitHeight + 24
                        color: "#102A3E"
                        radius: 7
                        border.color: "#345469"
                        ColumnLayout {
                            id: sectionColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 10
                            QGCLabel {
                                Layout.fillWidth: true
                                text: section.modelData.title
                                color: "#9ED9F2"
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.88 * root.textScale
                                font.bold: true
                                wrapMode: Text.WordWrap
                            }
                            Repeater {
                                model: section.specs
                                HQExtendedTuningField {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    tuningModel: parameterModel
                                    spec: modelData
                                    textScale: root.textScale
                                    sectionEnabled: !section.gate || Number(section.gate.rawValue) !== 0
                                        || spec.names.some(function(name) { return section.modelData.gate.indexOf(name) >= 0 })
                                }
                            }
                            QGCLabel {
                                Layout.fillWidth: true
                                visible: section.hint.length > 0
                                text: section.hint
                                color: "#C4B897"
                                wrapMode: Text.WordWrap
                                font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.74 * root.textScale
                            }
                        }
                    }
                }
            }
        }
        QGCLabel {
            Layout.fillWidth: true
            text: parameterModel.statusText
            visible: text.length > 0
            color: "#B8CBD6"
            wrapMode: Text.WordWrap
            font.pixelSize: ScreenTools.defaultFontPixelHeight * 0.74 * root.textScale
        }
        Flow {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 8
            QGCLabel {
                height: Math.max(44, ScreenTools.minTouchPixels)
                verticalAlignment: Text.AlignVCenter
                text: qsTr("Staged changes: %1").arg(parameterModel.pendingCount)
                color: "#B3D1E1"
            }
            QGCButton {
                objectName: "extendedReloadButton"
                text: qsTr("Reload parameters")
                enabled: !!parameterModel.vehicle
                onClicked: parameterModel.requestReload(root)
            }
            QGCButton {
                objectName: "extendedWriteButton"
                text: qsTr("Review and submit")
                enabled: parameterModel.canWrite && parameterModel.pendingCount > 0
                onClicked: parameterModel.requestWrite(root)
            }
        }
    }
}
