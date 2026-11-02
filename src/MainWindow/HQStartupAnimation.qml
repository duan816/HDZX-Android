pragma ComponentBehavior: Bound
import QGroundControl
import QGroundControl.Controls
import QtQuick

Item {
    id: root

    property bool _finished: false
    property bool autoStart: true
    property url logoSource: "/res/HDZXIntroLogo.png"
    property bool playing: false
    property real exitProgress: 0
    readonly property int totalDuration: 3000
    readonly property real unit: Math.min(ScreenTools.defaultFontPixelHeight * 1.3, Math.min(width, height) / 24)

    signal finished

    function finish() {
        if (_finished)
            return;
        _finished = true;
        playing = false;
        exitMotion.stop();
        lifetime.stop();
        finished();
    }

    anchors.fill: parent
    clip: true
    z: QGroundControl.zOrderTopMost + 1000

    // The scene stays centred while the assembled logo opens out in four directions.
    opacity: 1 - exitProgress

    Component.onCompleted: {
        if (autoStart)
            Qt.callLater(function () {
                if (root._finished)
                    return;
                root.playing = true;
                lifetime.start();
            });
    }

    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            GradientStop {
                color: "#070E1A"
                position: 0
            }

            GradientStop {
                color: "#101F34"
                position: 0.5
            }

            GradientStop {
                color: "#070E1A"
                position: 1
            }
        }
    }

    Item {
        id: identity

        anchors.centerIn: parent
        height: root.unit * 19
        objectName: "startupIdentity"
        width: Math.min(parent.width * 0.84, root.unit * 27)

        Item {
            id: mark

            anchors.horizontalCenter: parent.horizontalCenter
            height: width
            width: root.unit * 14
            scale: 1 + root.exitProgress * 0.18

            Repeater {
                model: 4

                delegate: Item {
                    id: fragment

                    readonly property int column: index % 2
                    required property int index
                    readonly property int row: Math.floor(index / 2)
                    objectName: "startupFragment_" + index

                    clip: true
                    height: mark.height / 2
                    opacity: 0
                    width: mark.width / 2
                    x: column * mark.width / 2
                    y: row * mark.height / 2

                    transform: [
                        Translate { id: pieceOffset },
                        Translate {
                            x: (fragment.column === 0 ? -1 : 1) * root.width * 0.48 * root.exitProgress
                            y: (fragment.row === 0 ? -1 : 1) * root.height * 0.48 * root.exitProgress
                        }
                    ]

                    Image {
                        fillMode: Image.PreserveAspectFit
                        height: mark.height
                        mipmap: true
                        source: root.logoSource
                        sourceSize: Qt.size(1024, 1024)
                        width: mark.width
                        x: -fragment.column * mark.width / 2
                        y: -fragment.row * mark.height / 2
                    }

                    SequentialAnimation {
                        running: root.playing

                        PauseAnimation {
                            duration: 100 + fragment.index * 65
                        }

                        ParallelAnimation {
                            OpacityAnimator {
                                duration: 230
                                from: 0
                                target: fragment
                                to: 1
                            }

                            NumberAnimation {
                                duration: 630
                                easing.type: Easing.OutCubic
                                from: (fragment.column === 0 ? -1 : 1) * root.unit * 4.5
                                property: "x"
                                target: pieceOffset
                                to: 0
                            }

                            NumberAnimation {
                                duration: 630
                                easing.type: Easing.OutCubic
                                from: (fragment.row === 0 ? -1 : 1) * root.unit * 3
                                property: "y"
                                target: pieceOffset
                                to: 0
                            }
                        }
                    }
                }
            }

            // A single clipped alpha image creates the sweep without blur/offscreen effects.
            Item {
                id: glint

                clip: true
                height: mark.height
                opacity: 0.38
                width: mark.width * 0.065
                x: -width

                QGCColoredImage {
                    color: "#C9E9FF"
                    height: mark.height
                    source: root.logoSource
                    width: mark.width
                    x: -glint.x
                }

                SequentialAnimation {
                    running: root.playing

                    PauseAnimation {
                        duration: 1110
                    }

                    NumberAnimation {
                        property: "x"
                        duration: 610
                        easing.type: Easing.InOutCubic
                        from: -glint.width
                        target: glint
                        to: mark.width
                    }
                }
            }

            Repeater {
                model: 12

                delegate: Rectangle {
                    id: spark

                    required property int index
                    readonly property real theta: index * Math.PI / 6

                    color: index % 3 === 0 ? "#FFBB42" : "#66B5FF"
                    height: width
                    opacity: 0
                    radius: width / 2
                    width: index % 3 === 0 ? 3 : 2
                    x: mark.width / 2 - width / 2
                    y: mark.height / 2 - height / 2

                    transform: Translate {
                        id: sparkOffset
                    }

                    SequentialAnimation {
                        running: root.playing

                        PauseAnimation {
                            duration: 60 + spark.index * 25
                        }

                        ParallelAnimation {
                            SequentialAnimation {
                                OpacityAnimator {
                                    duration: 150
                                    from: 0
                                    target: spark
                                    to: 0.75
                                }

                                PauseAnimation {
                                    duration: 350
                                }

                                OpacityAnimator {
                                    duration: 280
                                    target: spark
                                    to: 0
                                }
                            }

                            NumberAnimation {
                                duration: 780
                                easing.type: Easing.OutCubic
                                from: Math.cos(spark.theta) * mark.width * 0.78
                                property: "x"
                                target: sparkOffset
                                to: Math.cos(spark.theta) * mark.width * 0.32
                            }

                            NumberAnimation {
                                duration: 780
                                easing.type: Easing.OutCubic
                                from: Math.sin(spark.theta) * mark.height * 0.58
                                property: "y"
                                target: sparkOffset
                                to: Math.sin(spark.theta) * mark.height * 0.28
                            }
                        }
                    }
                }
            }
        }

        Column {
            id: caption

            anchors.top: mark.bottom
            anchors.topMargin: root.unit * 0.25
            opacity: 0
            spacing: root.unit * 0.4
            width: parent.width

            transform: Translate {
                id: captionOffset
            }

            Text {
                color: "#E3F1FF"
                font.letterSpacing: root.unit * (0.14 + root.exitProgress * 0.5)
                font.pixelSize: root.unit * 1.05
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                text: "HDZX  /  FLIGHT WORKSPACE"
                width: parent.width
            }

            Text {
                color: "#83B5DE"
                font.letterSpacing: root.unit * 0.035
                font.pixelSize: root.unit * 0.66
                horizontalAlignment: Text.AlignHCenter
                text: "DUANZHONGXU STUDIO  ·  段中旭工作室"
                width: parent.width
            }

            SequentialAnimation {
                running: root.playing

                PauseAnimation {
                    duration: 900
                }

                ParallelAnimation {
                    OpacityAnimator {
                        duration: 320
                        from: 0
                        target: caption
                        to: 1
                    }

                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.OutCubic
                        from: 12
                        property: "y"
                        target: captionOffset
                        to: 0
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
    }

    QGCButton {
        anchors.bottom: parent.bottom
        anchors.margins: root.unit
        anchors.right: parent.right
        bottomPadding: topPadding
        leftPadding: ScreenTools.defaultFontPixelWidth
        objectName: "startupSkipAnimation"
        pointSize: ScreenTools.smallFontPointSize
        rightPadding: ScreenTools.defaultFontPixelWidth
        text: qsTr("跳过加载动画")
        topPadding: ScreenTools.defaultFontPixelHeight * 0.2

        onClicked: root.finish()
    }

    NumberAnimation {
        id: exitMotion

        duration: 520
        easing.type: Easing.InOutCubic
        from: 0
        property: "exitProgress"
        target: root
        to: 1

        onFinished: root.finish()
    }

    Timer {
        id: lifetime

        interval: root.totalDuration - exitMotion.duration

        onTriggered: exitMotion.start()
    }
}
