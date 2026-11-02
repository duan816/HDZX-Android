import QtQuick
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls

/// The MissionLineView control is used to add lines between mission items
MapItemView {
    id: root
    property bool showSpecialVisual: false
    property bool planViewStyle: false
    property var selectedCoordinate: QtPositioning.coordinate()
    readonly property real foregroundWidth: planViewStyle ? ScreenTools.defaultFontPixelHeight * 0.16 : 3
    readonly property real outlineWidth: ScreenTools.defaultFontPixelHeight * 0.28
    delegate: MapItemGroup {
        id: segment
        z: QGroundControl.zOrderWaypointLines
        readonly property var flightPath: _calcMissionLinePath()
        readonly property bool selected: root.planViewStyle && root.selectedCoordinate.isValid && object
            && (root.selectedCoordinate.distanceTo(object.coordinate1) < 0.1 || root.selectedCoordinate.distanceTo(object.coordinate2) < 0.1)
        property color strokeColor: _terrainCollision ? "red" : root.planViewStyle
            ? (selected ? QGroundControl.globalPalette.planWaypointSelected : QGroundControl.globalPalette.planMissionTrajectory)
            : QGroundControl.globalPalette.mapMissionTrajectory
        Behavior on strokeColor {
            enabled: typeof mainWindow === "undefined" || mainWindow.hdzxNavigationAnimationsEnabled
            ColorAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        property bool _terrainCollision:    object && object.terrainCollision
        property bool _showSpecialVisual:   Boolean(object && showSpecialVisual && object.specialVisual)

        readonly property real _maxSegmentLengthM: 50000 // 50 km

        MapPolyline {
            visible: root.planViewStyle
            line.width: root.outlineWidth + (segment.selected ? 1 : 0)
            line.color: QGroundControl.globalPalette.planWaypointOutline
            path: segment.flightPath
        }
        MapPolyline {
            z: 0.1
            line.width: root.foregroundWidth + (segment.selected ? 0.8 : 0)
            // Collision warnings take precedence over the plan palette.
            line.color: segment.strokeColor
            path: segment.flightPath
        }

        function _calcMissionLinePath() {
            if (!object || !object.coordinate1.isValid || !object.coordinate2.isValid) {
                return []
            }

            var coord1 = object.coordinate1
            var coord2 = object.coordinate2

            var distance = coord1.distanceTo(coord2)
            if (distance <= _maxSegmentLengthM) {
                return [coord1, coord2]
            }

            // For longer distances, draw great circle path
            var pathPoints = [coord1]
            var numSegments = Math.ceil(distance / _maxSegmentLengthM)

            for (var i = 1; i < numSegments; i++) {
                var segmentDist = (i * distance) / numSegments
                var interpolatedCoord = coord1.atDistanceAndAzimuth(segmentDist, coord1.azimuthTo(coord2))
                pathPoints.push(interpolatedCoord)
            }

            pathPoints.push(coord2)
            return pathPoints
        }
    }
}
