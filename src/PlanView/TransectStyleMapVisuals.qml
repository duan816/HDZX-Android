import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

/// Base control for both Survey and Corridor Scan map visuals
Item {
    id: _root

    property var    map                                                 ///< Map control to place item in
    property bool   polygonInteractive: true
    property bool   interactive: true
    property var    vehicle
    property bool   hideMapPolygon: false
    property bool   showGeneratedWaypoints: false
    property var _generatedAnchor: null
    property var _generatedView: null
    readonly property var _generatedWaypoints: showGeneratedWaypoints && map.planView && _currentItem ? _missionItem.generatedWaypoints : []

    property var    _missionItem:               object
    property var    _mapPolygon:                object.surveyAreaPolygon
    property bool   _currentItem:               object.isCurrentItem
    property bool   _vertexDrag:                _mapPolygon.vertexDrag || hideMapPolygon
    property var    _transectPoints:            _missionItem.visualTransectPoints
    property int    _transectCount:             _transectPoints.length / (_hasTurnaround ? 4 : 2)
    property bool   _hasTurnaround:             _missionItem.turnAroundDistance.rawValue !== 0
    property int    _firstTrueTransectIndex:    _hasTurnaround ? 1 : 0
    property int    _lastTrueTransectIndex:     _transectPoints.length - (_hasTurnaround ? 2 : 1)
    property int    _lastPointIndex:            _transectPoints.length - 1
    property bool   _showPartialEntryExit:      !_currentItem && _hasTurnaround &&_transectPoints.length >= 2
    property var    _fullTransectsComponent:    null
    property var    _entryTransectsComponent:   null
    property var    _exitTransectsComponent:    null
    property var    _entryCoordinate
    property var    _exitCoordinate

    signal clicked(int sequenceNumber)

    function _addVisualElements() {
        var toAdd = [ fullTransectsComponent, entryTransectComponent, exitTransectComponent, entryPointComponent, exitPointComponent,
                     entryArrow1Component, entryArrow2Component, exitArrow1Component, exitArrow2Component ]
        objMgr.createObjects(toAdd, map, true /* parentObjectIsMap */)
        if (showGeneratedWaypoints && map.planView) {
            _generatedView = objMgr.createObject(generatedWaypointsComponent, map, false)
            map.addMapItemView(_generatedView)
            _generatedAnchor = objMgr.createObject(generatedAnchorComponent, map, true)
            objMgr.createObject(generatedDragComponent, map, false)
        }
    }

    function _destroyVisualElements() {
        if (_generatedView && map) map.removeMapItemView(_generatedView)
        _generatedView = null
        objMgr.destroyObjects()
    }

    Component.onCompleted: {
        _addVisualElements()
    }

    Component.onDestruction: {
        _destroyVisualElements()
    }

    QGCDynamicObjectManager {
        id: objMgr
    }

    // Area polygon
    QGCMapPolygonVisuals {
        id:                 mapPolygonVisuals
        mapControl:         map
        mapPolygon:         _mapPolygon
        interactive:        polygonInteractive && _missionItem.isCurrentItem && _root.interactive
        borderWidth:        1
        borderColor:        "black"
        interiorColor:      QGroundControl.globalPalette.surveyPolygonInterior
        altColor:           QGroundControl.globalPalette.surveyPolygonTerrainCollision
        interiorOpacity:    0.5 * _root.opacity
        visible:            !hideMapPolygon
    }

    // Full set of transects lines. Shown when item is selected.
    Component {
        id: fullTransectsComponent

        MapPolyline {
            line.color: map.planView ? QGroundControl.globalPalette.planMissionTrajectory : "white"
            line.width: map.planView ? 2.5 : 2
            path:       _transectPoints
            visible:    _currentItem && !_vertexDrag
            opacity:    _root.opacity
        }
    }

    // Entry and exit transect lines only. Used when item is not selected.
    Component {
        id: entryTransectComponent

        MapPolyline {
            line.color: "white"
            line.width: 2
            path:       _showPartialEntryExit ? [ _transectPoints[0], _transectPoints[1] ] : []
            visible:    _showPartialEntryExit && !_vertexDrag
            opacity:    _root.opacity
        }
    }
    Component {
        id: exitTransectComponent

        MapPolyline {
            line.color: "white"
            line.width: 2
            path:       _showPartialEntryExit ? [ _transectPoints[_lastPointIndex - 1], _transectPoints[_lastPointIndex] ] : []
            visible:    _showPartialEntryExit && !_vertexDrag
            opacity:    _root.opacity
        }
    }

    // Entry point
    Component {
        id: entryPointComponent

        MapQuickItem {
            anchorPoint.x:  sourceItem.anchorPointX
            anchorPoint.y:  sourceItem.anchorPointY
            z:              QGroundControl.zOrderMapItems
            coordinate:     _missionItem.coordinate
            visible:        !_generatedWaypoints.length && _missionItem.exitCoordinate.isValid && !_vertexDrag
            opacity:        _root.opacity

            sourceItem: MissionItemIndexLabel {
                index:      _missionItem.sequenceNumber
                checked:    _missionItem.isCurrentItem
                onClicked:  if(_root.interactive) _root.clicked(_missionItem.sequenceNumber)
            }
        }
    }

    Component {
        id: entryArrow1Component

        MapLineArrow {
            fromCoord:      _transectPoints[_firstTrueTransectIndex]
            toCoord:        _transectPoints[_firstTrueTransectIndex + 1]
            arrowPosition:  1
            visible:        _currentItem && !_vertexDrag
            opacity:        _root.opacity
        }
    }

    Component {
        id: entryArrow2Component

        MapLineArrow {
            fromCoord:      _transectPoints[nextTrueTransectIndex]
            toCoord:        _transectPoints[nextTrueTransectIndex + 1]
            arrowPosition:  1
            visible:        _currentItem && _transectCount > 3 && !_vertexDrag
            opacity:        _root.opacity

            property int nextTrueTransectIndex: _firstTrueTransectIndex + (_hasTurnaround ? 4 : 2)
        }
    }

    Component {
        id: exitArrow1Component

        MapLineArrow {
            fromCoord:      _transectPoints[_lastTrueTransectIndex - 1]
            toCoord:        _transectPoints[_lastTrueTransectIndex]
            arrowPosition:  3
            visible:        _currentItem && !_vertexDrag
            opacity:        _root.opacity
        }
    }

    Component {
        id: exitArrow2Component

        MapLineArrow {
            fromCoord:      _transectPoints[prevTrueTransectIndex - 1]
            toCoord:        _transectPoints[prevTrueTransectIndex]
            arrowPosition:  13
            visible:        _currentItem && _transectCount > 3 && !_vertexDrag
            opacity:        _root.opacity

            property int prevTrueTransectIndex: _lastTrueTransectIndex - (_hasTurnaround ? 4 : 2)
        }
    }

    // Exit point
    Component {
        id: exitPointComponent

        MapQuickItem {
            anchorPoint.x:  sourceItem.anchorPointX
            anchorPoint.y:  sourceItem.anchorPointY
            z:              QGroundControl.zOrderMapItems
            coordinate:     _missionItem.exitCoordinate
            visible:        !_generatedWaypoints.length && _missionItem.exitCoordinate.isValid && !_vertexDrag
            opacity:        _root.opacity

            sourceItem: MissionItemIndexLabel {
                index:      _missionItem.lastSequenceNumber
                checked:    _missionItem.isCurrentItem
                onClicked:  if(_root.interactive) _root.clicked(_missionItem.sequenceNumber)
            }
        }
    }

    Component {
        id: generatedWaypointsComponent
        MapItemView {
            model: _root._generatedWaypoints
            delegate: MapQuickItem {
                required property var modelData
                objectName: "hdzxSurveyPoint_" + modelData.sequenceNumber
                coordinate: modelData.coordinate
                anchorPoint.x: sourceItem.anchorPointX
                anchorPoint.y: sourceItem.anchorPointY
                z: QGroundControl.zOrderMapItems
                visible: !_root._vertexDrag
                opacity: _root.opacity
                sourceItem: PlanWaypointMarker {
                    index: modelData.sequenceNumber
                    checked: !!_missionItem.generatedWaypointEditor && _missionItem.generatedWaypointEditor.sequenceNumber === index
                    pinRadius: ScreenTools.defaultFontPixelHeight * 0.6
                    onClicked: {
                        if (!_root.interactive) return
                        const error = _missionItem.selectGeneratedWaypoint(modelData.sequenceNumber)
                        if (error.length) QGroundControl.showMessageDialog(mainWindow, qsTr("无法编辑航点"), error)
                    }
                }
            }
        }
    }

    Component {
        id: generatedDragComponent
        MissionItemIndicatorDrag {
            readonly property var editor: _root._currentItem ? _missionItem.generatedWaypointEditor : null
            mapControl: _root.map
            // A stable anchor survives preview delegate updates while a point is dragged.
            itemIndicator: _root._generatedAnchor
            itemCoordinate: editor ? editor.coordinate : QtPositioning.coordinate()
            visible: !!editor && _root.interactive
            onItemCoordinateChanged: if (editor && itemCoordinate.isValid) editor.coordinate = itemCoordinate
        }
    }

    Component {
        id: generatedAnchorComponent
      MapQuickItem {
        id: generatedAnchor
        readonly property var editor: showGeneratedWaypoints ? _missionItem.generatedWaypointEditor : null
        coordinate: editor ? editor.coordinate : QtPositioning.coordinate()
        anchorPoint.x: sourceItem.anchorPointX
        anchorPoint.y: sourceItem.anchorPointY
        sourceItem: PlanWaypointMarker {
            index: generatedAnchor.editor ? generatedAnchor.editor.sequenceNumber : -1
            checked: true
            pinRadius: ScreenTools.defaultFontPixelHeight * 0.6
            visible: false
        }
      }
    }
}
