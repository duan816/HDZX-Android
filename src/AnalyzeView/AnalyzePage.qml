import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

/// Base view control for all Analyze pages
Item {
    anchors.fill:               parent
    anchors.margins:            ScreenTools.defaultFontPixelWidth

    property alias  pageComponent:      pageLoader.sourceComponent
    property alias  pageDescription:    pageDescriptionLabel.text
    property alias  headerComponent:    headerLoader.sourceComponent
    property real   minimumContentWidth:  0
    property real   minimumContentHeight: 0
    property real   availableWidth:     Math.max(mainContent.width, minimumContentWidth)
    property real   availableHeight:    Math.max(mainContent.height, minimumContentHeight)
    property bool   allowPopout:        false
    property bool   popped:             false
    property real   _margins:           ScreenTools.defaultFontPixelHeight * 0.5

    signal popout()

    Loader {
        id:                     headerLoader
        anchors.topMargin:      _margins
        anchors.top:            parent.top
        anchors.left:           parent.left
        anchors.rightMargin:    _margins
        anchors.right:          floatIcon.visible ? floatIcon.left : parent.right
        visible:                !ScreenTools.isShortScreen && headerLoader.sourceComponent !== null
    }

    Column {
        id:                     headingColumn
        anchors.topMargin:      _margins
        anchors.top:            parent.top
        anchors.left:           parent.left
        anchors.rightMargin:    _margins
        anchors.right:          floatIcon.visible ? floatIcon.left : parent.right
        spacing:                _margins
        visible:                !ScreenTools.isShortScreen && headerLoader.sourceComponent === null
        QGCLabel {
            id:                 pageDescriptionLabel
            anchors.left:       parent.left
            anchors.right:      parent.right
            wrapMode:           Text.WordWrap
        }
    }

    QGCFlickable {
        id:                     mainContent
        objectName:             "analyzeContentViewport"
        anchors.topMargin:      ScreenTools.defaultFontPixelHeight
        anchors.top:            headerLoader.visible ? headerLoader.bottom : (headingColumn.visible ? headingColumn.bottom : parent.top)
        anchors.bottom:         parent.bottom
        anchors.left:           parent.left
        anchors.right:          parent.right
        clip:                   true
        // Keep the page's own chart/list gestures, but allow reaching content
        // which cannot fit the viewport (including short mobile landscape).
        contentWidth:           Math.max(width, pageLoader.item ? Math.max(pageLoader.item.width, pageLoader.item.implicitWidth) : 0)
        contentHeight:          Math.max(height, pageLoader.item ? Math.max(pageLoader.item.height, pageLoader.item.implicitHeight) : 0)
        flickableDirection:     Flickable.AutoFlickDirection
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        onContentWidthChanged: returnToBounds()
        onContentHeightChanged: returnToBounds()
        Loader {
            id:                 pageLoader
        }
    }

    QGCColoredImage {
        id:                     floatIcon
        anchors.verticalCenter: headerLoader.visible ? headerLoader.verticalCenter : headingColumn.verticalCenter
        anchors.right:          parent.right
        width:                  ScreenTools.defaultFontPixelHeight * 2
        height:                 width
        sourceSize.width:       width
        source:                 "/qmlimages/FloatingWindow.svg"
        fillMode:               Image.PreserveAspectFit
        color:                  qgcPal.text
        visible:                allowPopout && !popped && !ScreenTools.isMobile
        QGCMouseArea {
            fillItem:       floatIcon
            onClicked:      popout()
        }
    }
}
