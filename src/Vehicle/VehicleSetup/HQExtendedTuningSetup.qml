import QtQuick

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    readonly property bool handlesPageMotion: true
    transform: [
        Translate { x: pageMotion.offset },
        Rotation { origin.x: 0; origin.y: root.height / 2; axis: Qt.vector3d(0, 1, 0); angle: pageMotion.angle },
        Scale { origin.x: 0; origin.y: root.height / 2; xScale: pageMotion.surfaceScale; yScale: pageMotion.surfaceScale }
    ]
    HQParameterMotion {
        id: pageMotion
        objectName: "extendedPageMotion"
        targetItem: root
        foldDegrees: -7
        travel: 16
        duration: 300
        progress: 0
    }
    // Materialize the dense Fact controls before revealing them; follow display cadence.
    FrameAnimation {
        property int frames: 0
        running: true
        onTriggered: {
            if (++frames < 2) return
            running = false
            pageMotion.reveal()
        }
    }

    HQExtendedTuningWorkspace {
        objectName: "fixedExtendedTuningWorkspace"
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
    }
}
