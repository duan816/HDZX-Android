pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick3D
import QtPositioning
import QGroundControl
import QGroundControl.Controls
import QGroundControl.GeoMap

Item {
    id: root
    objectName: "flightGeoScene"
    property bool flightView: false
    property var missionItems: null
    readonly property var vehicles: QGroundControl.multiVehicleManager.vehicles
    readonly property var focusedVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var initialPose: null
    signal viewChanged(var pose)
    property bool showTrails: true
    property string mapType: ""

    property var initialCenter: QtPositioning.coordinate()
    property int projectionRevision: 0
    property real ignoreTapUntil: 0
    property var trailOffsets: ({})
    readonly property int patchCount: geo.patchCount
    readonly property int pendingCount: geo.pendingCount
    readonly property int imageryTileCount: geo.imageryTileCount
    readonly property int vehicleModelCount: droneModels.count
    readonly property alias camera: geo.camera
    signal vehicleChosen(int vehicleId)
    clip: true

    function colorFor(id) { return ["#70C8F5", "#B8A3F4", "#F3C07A", "#7CD6B2", "#EE91BA", "#9CC7D4"][Math.abs(id) % 6] }
    function positionFor(vehicle) {
        if (!vehicle || !vehicle.coordinate.isValid) return QtPositioning.coordinate()
        const altitude = vehicle.altitudeAMSL ? Number(vehicle.altitudeAMSL.rawValue) : NaN
        return QtPositioning.coordinate(vehicle.coordinate.latitude, vehicle.coordinate.longitude, isFinite(altitude) ? altitude : 0)
    }
    function project(coordinate) {
        const revision = projectionRevision
        return coordinate && coordinate.isValid ? geo.scene.screenPositionFor(coordinate) : null
    }
    function centerAt(coordinate, distance) {
        if (!coordinate || !coordinate.isValid) return
        geo.camera.center = coordinate
        geo.camera.distance = Math.max(distance || 800, isFinite(coordinate.altitude) ? coordinate.altitude * 2.5 + 600 : 800)
    }
    function zoom(amount) { geo.camera.zoom(amount, Qt.point(width / 2, height / 2)) }
    function clearTrails() {
        const offsets = {}
        if (vehicles) {
            for (let i = 0; i < vehicles.count; ++i) {
                const vehicle = vehicles.get(i)
                if (vehicle && vehicle.trajectoryPoints) offsets[vehicle.id] = vehicle.trajectoryPoints.list().length
            }
        }
        trailOffsets = offsets
        refresh()
    }
    function refresh() { if (!redraw.running) redraw.start() }
    function choose(id) { ignoreTapUntil = Date.now() + 200; vehicleChosen(id) }
    Component.onCompleted: {
        if (initialCenter.isValid) geo.camera.center = initialCenter
        geo.camera.mode = GeoMapCamera.Mode3D
        const aircraft = positionFor(focusedVehicle)
        geo.camera.distance = aircraft.isValid && isFinite(aircraft.altitude) ? Math.max(900, aircraft.altitude * 2.5 + 600) : 900
        if (initialPose) {
            geo.completeCameraAnimations()
            geo.camera.center = QtPositioning.coordinate(initialPose.latitude, initialPose.longitude, initialPose.altitude || 0)
            geo.camera.distance = initialPose.distance
            geo.camera.heading = initialPose.heading
            geo.camera.tilt = initialPose.tilt
        }
    }
    function currentPose() {
        const c = geo.camera.center
        return {latitude: c.latitude, longitude: c.longitude, altitude: isFinite(c.altitude) ? c.altitude : 0,
                distance: geo.camera.distance, heading: geo.camera.heading, tilt: geo.camera.tilt}
    }
    function publishPose() { if (geo.camera.center.isValid) viewChanged(currentPose()) }
    Component.onDestruction: publishPose()
    Timer { id: savePose; interval: 250; onTriggered: root.publishPose() }

    onShowTrailsChanged: refresh()
    Timer { id: redraw; interval: 50; onTriggered: { ++root.projectionRevision; paths.requestPaint() } }

    GeoMap {
        id: geo
        objectName: "flightGeoMap"
        anchors.fill: parent
        initialCenter: root.initialPose ? QtPositioning.coordinate(root.initialPose.latitude, root.initialPose.longitude)
            : root.initialCenter.isValid ? root.initialCenter : QGroundControl.flightMapPosition
        mapType: root.mapType

    }
    Connections { target: geo.camera; function onScenePoseChanged() { root.refresh(); savePose.restart() } }
    Connections { target: geo.scene; function onSceneOriginChanged() { root.refresh() } }


    Node {
        parent: geo.sceneContent
        Repeater3D {
            id: droneModels
            model: root.vehicles
            delegate: HQFlightDrone3D {
                id: drone
                required property var object
                readonly property var coordinate: root.positionFor(object)
                visible: coordinate.isValid
                vehicle: object
                position: {
                    const origin = geo.scene.sceneOrigin
                    return coordinate.isValid ? geo.scene.scenePositionFor(coordinate) : Qt.vector3d(0, 0, 0)
                }
                heading: object && object.heading && isFinite(Number(object.heading.rawValue)) ? Number(object.heading.rawValue) : 0
                roll: object && object.roll && isFinite(Number(object.roll.rawValue)) ? Number(object.roll.rawValue) : 0
                pitch: object && object.pitch && isFinite(Number(object.pitch.rawValue)) ? Number(object.pitch.rawValue) : 0
                modelScale: {
                    const distance = geo.camera.distance
                    const viewport = geo.camera.viewportSize
                    return Math.max(0.4, Math.min(10, geo.camera.sceneUnitsPerPixel() * 3.2))
                }
                Connections {
                    target: drone.object
                    function onCoordinateChanged() { root.refresh() }
                    function onHomePositionChanged() { root.refresh() }
                }
                Connections {
                    target: drone.object ? drone.object.trajectoryPoints : null
                    function onPointAdded(coordinate) { root.refresh() }
                    function onUpdateLastPoint(coordinate) { root.refresh() }
                    function onPointsCleared() { root.refresh() }
                }
            }
        }
    }

    Canvas {
        id: paths
        anchors.fill: parent
        function drawPath(ctx, coordinates, color, dashed) {
            ctx.beginPath(); ctx.strokeStyle = color; ctx.lineWidth = 2
            ctx.setLineDash(dashed ? [7, 5] : [])
            let started = false
            for (const coordinate of coordinates) {
                const point = root.project(coordinate)
                if (!point) { started = false; continue }
                if (!started) { ctx.moveTo(point.x, point.y); started = true }
                else ctx.lineTo(point.x, point.y)
            }
            ctx.stroke()
        }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset(); ctx.clearRect(0, 0, width, height)
            if (!root.vehicles) return
            for (let i = 0; i < root.vehicles.count; ++i) {
                const vehicle = root.vehicles.get(i)
                if (!vehicle) continue
                if (root.showTrails && vehicle.trajectoryPoints) drawPath(ctx, vehicle.trajectoryPoints.list().slice(root.trailOffsets[vehicle.id] || 0).slice(-1500), root.colorFor(vehicle.id), false)
                if (vehicle.homePosition.isValid && vehicle.flightMode === vehicle.rtlFlightMode) drawPath(ctx, [root.positionFor(vehicle), vehicle.homePosition], "#E3BC75", true)
            }

            if (root.flightView && root.missionItems) {
                const coordinates = []
                for (let j = 0; j < root.missionItems.count; ++j) {
                    const item = root.missionItems.get(j)
                    if (item && item.specifiesCoordinate && item.coordinate.isValid) {
                        const c = item.coordinate
                        const alt = Number(item.amslEntryAlt)
                        coordinates.push(QtPositioning.coordinate(c.latitude, c.longitude,
                            isFinite(alt) ? alt : 0))
                    }
                }
                drawPath(ctx, coordinates, "#E3BC75", false)
            }
        }
    }
    Repeater {
        model: root.vehicles
        delegate: Item {
            id: marker
            required property var object
            readonly property var point: root.project(root.positionFor(object))
            readonly property var homePoint: root.project(object ? object.homePosition : null)
            readonly property bool focused: !!object && !!root.focusedVehicle && root.focusedVehicle.id === object.id
            x: point ? point.x - 28 : -100
            y: point ? point.y - 28 : -100
            width: 56; height: 70
            visible: !!point
            Label { anchors.horizontalCenter: parent.horizontalCenter; y: 48; text: marker.object ? qsTr("%1号").arg(marker.object.id) : ""; color: marker.focused ? "#B6DEFF" : "#FFFFFF"; style: Text.Outline; styleColor: "#102030"; font.pixelSize: 13; font.bold: true }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (marker.object) root.choose(marker.object.id) }
            Rectangle {
                parent: root
                visible: !!marker.homePoint && marker.focused
                x: marker.homePoint ? marker.homePoint.x - 17 : -100
                y: marker.homePoint ? marker.homePoint.y - 17 : -100
                width: 34; height: 34; radius: 17
                color: "#50FFD400"; border.color: "#FFE000"; border.width: 3
                Label { anchors.centerIn: parent; text: marker.object ? "H" : ""; color: "#FFF27A"; font.pixelSize: 17; font.bold: true }
            }
        }
    }


    Label {
        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 8
        text: qsTr("地形：Mapzen/Tilezen · NASA/USGS/NOAA")
        color: "#C4D3E1"; font.pixelSize: 10
    }
}
