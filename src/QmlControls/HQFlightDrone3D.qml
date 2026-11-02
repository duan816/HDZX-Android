pragma ComponentBehavior: Bound

import QtQuick
import QtQuick3D
import QGroundControl.Viewer3D

Node {
    id: root
    property real heading: 0
    property real roll: 0
    property real pitch: 0
    property real modelScale: 1
    property var vehicle: null
    readonly property string modelStyle: "DJI F450 · two red front arms, two white rear arms"
    // The original CAD mesh is millimetre-sized; preserve its existing axis
    // conversion, then fit the same screen footprint as our map markers.
    DroneModelDjiF450 {
        objectName: "terrainF450Model"
        localOnly: true
        vehicle: root.vehicle
        heading: root.heading
        roll: root.roll
        pitch: root.pitch
        modelScale: Qt.vector3d(root.modelScale * 0.018, root.modelScale * 0.018, root.modelScale * 0.018)
    }
}
