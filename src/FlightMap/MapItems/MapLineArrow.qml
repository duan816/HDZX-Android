import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

MapQuickItem {
    id: root
    property bool planViewStyle: false
    property color  arrowColor:     "white"
    property var    fromCoord:      QtPositioning.coordinate()
    property var    toCoord:        QtPositioning.coordinate()
    property int    arrowPosition:  1 ///< 1: first quarter, 2: halfway, 3: last quarter

    property var    _map:           parent
    property real   _arrowSize:     planViewStyle ? ScreenTools.defaultFontPixelHeight * 0.6 : 15
    property real   _arrowHeading:  0

    function _updateArrowDetails() {
        if (fromCoord && fromCoord.isValid && toCoord && toCoord.isValid) {
            var lineDistanceQuarter = fromCoord.distanceTo(toCoord) / 4
            coordinate = fromCoord.atDistanceAndAzimuth(lineDistanceQuarter * arrowPosition, fromCoord.azimuthTo(toCoord))
            _arrowHeading = coordinate.azimuthTo(toCoord) // Account for changing bearing along great circle path
        } else {
            coordinate = QtPositioning.coordinate()
            _arrowHeading = 0
        }
    }

    onFromCoordChanged: _updateArrowDetails()
    onToCoordChanged:   _updateArrowDetails()
    onArrowColorChanged: arrowCanvas.requestPaint()
    onPlanViewStyleChanged: arrowCanvas.requestPaint()

    sourceItem: Canvas {
        id: arrowCanvas
        x:      -_arrowSize
        y:      0
        width:  _arrowSize * 2
        height: _arrowSize

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height)
            ctx.beginPath();
            ctx.moveTo(0, _arrowSize)
            ctx.lineTo(_arrowSize, 0)
            ctx.lineTo(_arrowSize * 2, _arrowSize)
            if (root.planViewStyle) {
                ctx.lineWidth = ScreenTools.defaultFontPixelWidth * 0.5
                ctx.strokeStyle = QGroundControl.globalPalette.planWaypointOutline
                ctx.stroke()
            }
            ctx.lineWidth = 2
            ctx.strokeStyle = arrowColor
            ctx.stroke();
        }

        transform: Rotation {
            origin.x:   width / 2
            origin.y:   0
            angle:      _arrowHeading
        }
    }
}
