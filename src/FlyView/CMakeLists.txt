# ============================================================================
# Flight Display Module
# In-flight view, telemetry displays, and vehicle control UI
# ============================================================================

qt_add_library(FlyViewModule STATIC)

qt_add_qml_module(FlyViewModule
    URI QGroundControl.FlyView
    VERSION 1.0
    RESOURCE_PREFIX /qml
    QML_FILES
        CustomGuidedActionsController.qml
        DefaultChecklist.qml
        FixedWingChecklist.qml
        FlightDisplayViewDummy.qml
        FlightDisplayViewVideoOutput.qml
        FlightDisplayViewQtMultimedia.qml
        FlightDisplayViewUVC.qml
        FlightDisplayViewVideo.qml
        FlyView.qml
        FlyViewAdditionalActionsButton.qml
        FlyViewAdditionalActionsList.qml
        FlyViewAdditionalActionsPanel.qml
        FlyViewAdditionalCustomActionsList.qml
        FlyViewBottomRightRowLayout.qml
        FlyViewCustomLayer.qml
        FlyViewGeo.qml
        FlyViewGeoMap.qml
        FlyViewInsetViewer.qml
        FlyViewInstrumentPanel.qml
        FlyViewGripperButton.qml
        FlyViewGripperDropPanel.qml
        FlyViewMap.qml
        FlyViewMissionCompleteDialog.qml
        FlyViewPreFlightChecklistPopup.qml
        FlyViewToolStrip.qml
        FlyViewToolStripActionList.qml

        FlyViewTopRightColumnLayout.qml
        FlyViewTopRightPanel.qml
        FlyViewVideo.qml
        FlyViewWidgetLayer.qml
        GuidedActionConfirm.qml
        GuidedActionLand.qml
        GuidedActionPause.qml
        GuidedActionRTL.qml
        GuidedActionsController.qml
        GuidedActionTakeoff.qml
        GuidedToolStripAction.qml
        GuidedValueSlider.qml
        HQHud.qml
        HQClassicHud.qml
        HQHudScene.qml
        HQWarningPresentation.js
        HQHudDiagnostics.qml
        HQPidMonitor.qml
        HQExtendedTuning.qml
        HQFullScreenControl.qml
        HQToolWarehouse.qml
        HQVehicleCard.qml
        HQFlightSetupMenu.qml
        HQFlightSettingsDrawer.qml
        HQSetupIcon.qml
        HQToolIcon.qml
        HQSatelliteIcon.qml
        HQDetachedInstrument.qml
        HQVehicleConfigSidebar.qml
        HQResizeHandle.qml
        HQInstrumentDragArea.qml
        HQPanelMotion.qml
        HQInstrumentOrder.qml
        HQFlightDashboard.qml
        HQCompositeDashboard.qml
        HQDashboardMath.js
        HQDashboardTheme.js
        HQDashboardHeightHandle.qml
        HQLinearInstrument.qml
        HQAngularSpeed.qml
        HQRebootVehicleAction.qml
        MultiRotorChecklist.qml
        MultiVehicleList.qml
        ObstacleDistanceOverlay.qml
        ObstacleDistanceOverlayMap.qml
        ObstacleDistanceOverlayVideo.qml
        OnScreenCameraTrackingController.qml
        OnScreenGimbalController.qml
        PreFlightBatteryCheck.qml
        PreFlightCheckList.qml
        PreFlightCheckListShowAction.qml
        PreFlightGPSCheck.qml
        PreFlightRCCheck.qml
        PreFlightSensorsHealthCheck.qml
        PreFlightSoundCheck.qml
        ProximityRadarValues.qml
        ProximityRadarVideoView.qml
        RoverChecklist.qml
        SubChecklist.qml
        TelemetryValuesBar.qml
        TerrainProgress.qml
        VehicleWarnings.qml
        VirtualJoystick.qml
        VTOLChecklist.qml
    NO_PLUGIN
)

qt_add_resources(FlyViewModule flyview_resources
    PREFIX "/res"
    BASE "${CMAKE_SOURCE_DIR}/resources"
    FILES
        "${CMAKE_SOURCE_DIR}/resources/Gripper.svg"
        "${CMAKE_SOURCE_DIR}/resources/land.svg"
        "${CMAKE_SOURCE_DIR}/resources/NoVideoBackground.jpg"
        "${CMAKE_SOURCE_DIR}/resources/pause-mission.svg"
        "${CMAKE_SOURCE_DIR}/resources/PowerButton.svg"
)

qt_add_resources(FlyViewModule flyview_qmlimages
    PREFIX "/qmlimages"
    BASE "${CMAKE_SOURCE_DIR}/resources"
    FILES
        "${CMAKE_SOURCE_DIR}/resources/check.svg"
)
