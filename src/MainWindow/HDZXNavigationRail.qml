pragma ComponentBehavior: Bound
import QGroundControl
import QGroundControl.Controls
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    readonly property real uiScale: ScreenTools.mobileUiScale

    readonly property int activeIndex: entries.findIndex(function (entry) {
        return entry.key === root.section;
    })
    readonly property var entries: [
        {
            key: "flight",
            title: qsTr("Flight"),
            icon: "flight"
        },
        {
            key: "plan",
            title: qsTr("Mission"),
            icon: "mission"
        },
        {
            key: "setup",
            title: qsTr("Configure"),
            icon: "configure"
        },
        {
            key: "analyze",
            title: qsTr("Analyze"),
            icon: "analyze"
        },
        {
            key: "settings",
            title: qsTr("应用设置"),
            icon: "settings"
        },
        {
            key: "ai",
            title: qsTr("AI Tuning"),
            icon: "ai"
        }
    ]
    property bool indicatorReady: false
    readonly property real indicatorY: selectionSurface.y
    property bool mobileGestures: false
    property string section: "flight"

    readonly property Item selectedEntry: indicatorReady && activeIndex >= 0 ? navRepeater.itemAt(activeIndex) : null
    property real swipeStartIndex: 0
    property bool swiping: false

    signal navigateRequested(string destination)
    signal swipeNavigateRequested(string destination)
    signal manualConnectionRequested

    function finishSwipe(distance, velocity) {
        const stride = (selectedEntry ? selectedEntry.height : 48) + navigationColumn.spacing;
        const fraction = distance / stride;
        let steps = Math.round(fraction);
        if (steps === 0 && Math.abs(distance) >= 18 && Math.abs(velocity) > 700)
            steps = distance > 0 ? 1 : -1;
        const index = Math.max(0, Math.min(entries.length - 1, swipeStartIndex + steps));
        swiping = false;
        if (index !== activeIndex)
            swipeNavigateRequested(entries[index].key);
        // Also returns to the current page if validation blocks a navigation.
        updateSelection();
    }

    function updateSelection() {
        if (!selectedEntry || swiping)
            return;
        selectionSurface.moveTo(selectedEntry.y, selectedEntry.height);
        if (selectedEntry.y < navigationViewport.contentY)
            navigationViewport.contentY = selectedEntry.y;
        else if (selectedEntry.y + selectedEntry.height > navigationViewport.contentY + navigationViewport.height)
            navigationViewport.contentY = selectedEntry.y + selectedEntry.height - navigationViewport.height;
    }



    color: "#10151f"

    Component.onCompleted: Qt.callLater(function () {
        root.indicatorReady = true;
        root.updateSelection();
    })
    onSelectedEntryChanged: Qt.callLater(updateSelection)

    Rectangle {
        anchors.right: parent.right
        color: "#263247"
        height: parent.height
        width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8 * root.uiScale
        spacing: 8 * root.uiScale

        AbstractButton {
            id: connectionButton
            Layout.fillWidth: true
            Layout.preferredHeight: 88 * root.uiScale
            objectName: "hdzxManualConnection"
            hoverEnabled: !ScreenTools.isMobile
            Accessible.name: qsTr("手动连接")
            Accessible.description: qsTr("打开连接设置，选择串口、UDP 或 TCP 连接飞控")
            onClicked: root.manualConnectionRequested()
            ToolTip.visible: !ScreenTools.isMobile && hovered
            ToolTip.text: qsTr("手动连接")
            background: Rectangle {
                radius: 10
                color: connectionButton.pressed ? "#203f64" : connectionButton.hovered ? "#182a40" : "transparent"
                border.width: connectionButton.visualFocus ? 1 : 0
                border.color: "#7ab8ff"
            }

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                fillMode: Image.PreserveAspectFit
                height: 54 * root.uiScale
                mipmap: true
                source: "qrc:/res/HQLogo.png"
                sourceSize: Qt.size(128, 128)
                width: 54 * root.uiScale
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#e9eff8"
                font.letterSpacing: 2 * root.uiScale
                font.pointSize: 12 * root.uiScale
                font.weight: Font.DemiBold
                text: "HDZX"
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#263247"
        }

        Flickable {
            id: navigationViewport
            objectName: "hdzxNavigationViewport"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 48 * root.uiScale
            Layout.preferredHeight: navigationColumn.implicitHeight
            Layout.maximumHeight: navigationColumn.implicitHeight
            contentWidth: width
            contentHeight: navigationColumn.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            onHeightChanged: Qt.callLater(root.updateSelection)
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Item {
                id: selectionSurface

                readonly property real baseHeight: root.selectedEntry ? root.selectedEntry.height : 48
                property real bottomEdge: 0
                property bool forward: true
                property bool positioned: false
                property real targetBottom: 0
                property real targetTop: 0
                property real topEdge: 0

                function moveTo(top, size) {
                    if (positioned && Math.abs(targetTop - top) < 0.01 && Math.abs(targetBottom - top - size) < 0.01 && !root.swiping)
                        return;
                    flow.stop();
                    forward = top >= topEdge;
                    targetTop = top;
                    targetBottom = top + size;
                    if (!positioned) {
                        topEdge = targetTop;
                        bottomEdge = targetBottom;
                        positioned = true;
                    } else
                        flow.start();
                }

                height: Math.max(1, Math.abs(bottomEdge - topEdge))
                objectName: "hdzxNavigationSelection"
                visible: positioned && root.selectedEntry !== null
                width: parent.width
                y: Math.min(topEdge, bottomEdge)

                Rectangle {
                    color: "#203f64"
                    height: selectionSurface.baseHeight
                    radius: 16
                    width: parent.width

                    transform: Scale {
                        origin.x: selectionSurface.width / 2
                        xScale: Math.max(0.9, 1 - Math.abs(selectionSurface.height / selectionSurface.baseHeight - 1) * 0.045)
                        yScale: selectionSurface.height / selectionSurface.baseHeight
                    }
                }

                ParallelAnimation {
                    id: flow

                    SequentialAnimation {
                        PauseAnimation {
                            duration: selectionSurface.forward ? 28 : 0
                        }

                        NumberAnimation {
                            duration: selectionSurface.forward ? 232 : 175
                            easing.overshoot: 0.35
                            easing.type: selectionSurface.forward ? Easing.OutBack : Easing.OutCubic
                            property: "topEdge"
                            target: selectionSurface
                            to: selectionSurface.targetTop
                        }
                    }

                    SequentialAnimation {
                        PauseAnimation {
                            duration: selectionSurface.forward ? 0 : 28
                        }

                        NumberAnimation {
                            duration: selectionSurface.forward ? 175 : 232
                            easing.overshoot: 0.35
                            easing.type: selectionSurface.forward ? Easing.OutCubic : Easing.OutBack
                            property: "bottomEdge"
                            target: selectionSurface
                            to: selectionSurface.targetBottom
                        }
                    }
                }
            }

            // Restricted to the left rail: never takes a map drag or a parameter scroll.
            DragHandler {
                id: pageSwipe

                property real dragDistance: 0
                property real dragVelocity: 0

                acceptedDevices: PointerDevice.TouchScreen
                enabled: root.mobileGestures && navigationViewport.contentHeight <= navigationViewport.height
                objectName: "hdzxPageSwipe"
                target: null
                xAxis.enabled: false
                yAxis.enabled: true

                onActiveChanged: {
                    if (active) {
                        dragDistance = 0;
                        dragVelocity = 0;
                        root.swiping = true;
                        root.swipeStartIndex = Math.max(0, root.activeIndex);
                        flow.stop();
                    } else if (root.swiping) {
                        root.finishSwipe(dragDistance, dragVelocity);
                    }
                }
                onActiveTranslationChanged: {
                    if (!active || !root.selectedEntry)
                        return;
                    dragDistance = activeTranslation.y;
                    dragVelocity = centroid.velocity.y;
                    const stride = root.selectedEntry.height + navigationColumn.spacing;
                    const index = Math.max(0, Math.min(root.entries.length - 1, root.swipeStartIndex + activeTranslation.y / stride));
                    const top = index * stride;
                    selectionSurface.topEdge = top;
                    selectionSurface.bottomEdge = top + root.selectedEntry.height;
                    // Force a snap even if the gesture returns to the current target.
                    selectionSurface.targetTop = -1;
                }
                onCanceled: {
                    root.swiping = false;
                    selectionSurface.targetTop = -1;
                    root.updateSelection();
                }
            }

            Column {
                id: navigationColumn

                spacing: 8 * root.uiScale
                width: parent.width

                Repeater {
                    id: navRepeater

                    model: root.entries

                    delegate: Button {
                        id: entry

                        required property var modelData
                        property bool selected: root.section === modelData.key

                        Accessible.name: modelData.title
                        ToolTip.delay: 700
                        ToolTip.text: modelData.title
                        ToolTip.visible: !ScreenTools.isMobile && hovered
                        focusPolicy: ScreenTools.isMobile ? Qt.NoFocus : Qt.StrongFocus
                        height: Math.max(60 * root.uiScale, Math.min(68 * root.uiScale, (root.height - 230 * root.uiScale) / root.entries.length))
                        hoverEnabled: !ScreenTools.isMobile
                        objectName: "hdzxNav_" + modelData.key
                        width: navigationColumn.width

                        Binding {
                            target: entry
                            property: "padding"
                            value: 0
                            when: ScreenTools.isMobile
                        }

                        Binding { target: entry; property: "leftPadding"; value: 0; when: ScreenTools.isMobile }
                        Binding { target: entry; property: "rightPadding"; value: 0; when: ScreenTools.isMobile }
                        Binding { target: entry; property: "topPadding"; value: 0; when: ScreenTools.isMobile }
                        Binding { target: entry; property: "bottomPadding"; value: 0; when: ScreenTools.isMobile }

                        Binding { target: entry; property: "topInset"; value: 0; when: ScreenTools.isMobile }
                        Binding { target: entry; property: "bottomInset"; value: 0; when: ScreenTools.isMobile }
                        Binding { target: entry; property: "leftInset"; value: 0; when: ScreenTools.isMobile }
                        Binding { target: entry; property: "rightInset"; value: 0; when: ScreenTools.isMobile }

                        background: Rectangle {
                            border.color: "#80b9ff"
                            border.width: !ScreenTools.isMobile && entry.visualFocus ? 1 : 0
                            color: entry.hovered && !entry.selected ? "#1c2738" : "transparent"
                            radius: 14
                            scale: entry.down ? 0.96 : 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: 130
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }

                            HQButtonRipple {
                                control: entry
                            }
                        }
                        contentItem: Item {
                            Column {
                                objectName: "hdzxNavContent_" + entry.modelData.key
                                width: parent.width
                                y: ScreenTools.isMobile ? (parent.height - implicitHeight) / 2 : 0
                                spacing: 6 * root.uiScale

                                QGCColoredImage {
                                    id: entryIcon

                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: entry.selected ? "#86bdff" : "#a7b7cc"
                                    height: 23 * root.uiScale
                                    source: "qrc:/hdzx/" + entry.modelData.icon + ".svg"
                                    width: 23 * root.uiScale

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 160
                                        }
                                    }
                                }

                                Text {
                                    color: entry.selected ? "#e9eff8" : "#a7b7cc"
                                    elide: Text.ElideNone
                                    font.pointSize: 9 * root.uiScale
                                    font.weight: entry.selected ? Font.DemiBold : Font.Normal
                                    horizontalAlignment: Text.AlignHCenter
                                    text: entry.modelData.title
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                    width: parent.width

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 160
                                        }
                                    }
                                }
                        }

                        }

                        onClicked: root.navigateRequested(modelData.key)
                        onHeightChanged: if (selected)
                            Qt.callLater(root.updateSelection)
                        onSelectedChanged: {
                            if (selected && root.indicatorReady)
                                iconSelect.restart();
                        }
                        onYChanged: if (selected)
                            Qt.callLater(root.updateSelection)

                        SequentialAnimation {
                            id: iconSelect

                            NumberAnimation {
                                duration: 55
                                easing.type: Easing.OutCubic
                                property: "scale"
                                target: entryIcon
                                to: 0.86
                            }

                            NumberAnimation {
                                duration: 175
                                easing.overshoot: 0.65
                                easing.type: Easing.OutBack
                                property: "scale"
                                target: entryIcon
                                to: 1
                            }
                        }
                    }
                }


            }
        }

        Item {
            Layout.fillHeight: true
        }

        Button {
            Accessible.name: text
            Layout.fillWidth: true
            Layout.preferredHeight: 48 * root.uiScale
            font.pointSize: 9 * root.uiScale
            hoverEnabled: !ScreenTools.isMobile
            text: qsTr("All tools")

            background: Rectangle {
                color: parent.hovered ? "#1c2738" : "#182130"
                radius: 12
            }
            contentItem: Text {
                color: "#a7b7cc"
                font: parent.font
                horizontalAlignment: Text.AlignHCenter
                text: parent.text
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: root.navigateRequested("tools")
        }

        Text {
            Layout.bottomMargin: 6 * root.uiScale
            Layout.fillWidth: true
            color: "#8295ae"
            font.pointSize: 7 * root.uiScale
            horizontalAlignment: Text.AlignHCenter
            text: "NATIVE · 2.0"
        }
    }
}
