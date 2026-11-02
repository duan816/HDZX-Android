import QGroundControl
import QGroundControl.Controls

ToolStripAction {
    id: root

    objectName: "flyToolStrip_viewer3DButton"

    property bool _is3DViewOpen: QGCViewer3DManager.displayMode === QGCViewer3DManager.View3D
    property bool _viewer3DEnabled: QGroundControl.settingsManager.viewer3DSettings.enabled.rawValue

    iconSource: _is3DViewOpen ? "/qmlimages/PaperPlane.svg" : "/qml/QGroundControl/Viewer3D/City3DMapIcon.svg"
    text: _is3DViewOpen ? qsTr("2D 地图") : qsTr("3D 地图")
    visible: true

    onTriggered: {
        if (_is3DViewOpen) {
            QGCViewer3DManager.setDisplayMode(QGCViewer3DManager.Map);
        } else {
            QGCViewer3DManager.setDisplayMode(QGCViewer3DManager.View3D);
        }
    }
}
