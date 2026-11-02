#include "QGCPalette.h"
#include "QGCCorePlugin.h"

#include <QtCore/QDebug>

QList<QGCPalette*>   QGCPalette::_paletteObjects;

QGCPalette::Theme QGCPalette::_theme = QGCPalette::Dark;

QMap<int, QMap<int, QMap<QString, QColor>>> QGCPalette::_colorInfoMap;

QStringList QGCPalette::_colors;

QGCPalette::QGCPalette(QObject* parent) :
    QObject(parent),
    _colorGroupEnabled(true)
{
    if (_colorInfoMap.isEmpty()) {
        _buildMap();
    }

    // We have to keep track of all QGCPalette objects in the system so we can signal theme change to all of them
    _paletteObjects += this;
}

QGCPalette::~QGCPalette()
{
    bool fSuccess = _paletteObjects.removeOne(this);
    if (!fSuccess) {
        qWarning() << "Internal error";
    }
}

void QGCPalette::_buildMap()
{
    //                                      Light                 Dark
    //                                      Disabled   Enabled    Disabled   Enabled
    DECLARE_QGC_COLOR(window,               "#f5f7fb", "#f5f7fb", "#10151f", "#10151f")
    DECLARE_QGC_COLOR(windowTransparent,    "#edf5f7fb", "#edf5f7fb", "#ed10151f", "#ed10151f")
    DECLARE_QGC_COLOR(windowShadeLight,     "#9aa9ba", "#8498b0", "#30415a", "#30415a")
    DECLARE_QGC_COLOR(windowShade,          "#e4eaf3", "#e4eaf3", "#182130", "#182130")
    DECLARE_QGC_COLOR(windowShadeDark,      "#ccd7e6", "#ccd7e6", "#121a26", "#121a26")
    DECLARE_QGC_COLOR(text,                 "#7a8797", "#18253a", "#7989a0", "#e9eff8")
    DECLARE_QGC_COLOR(warningText,          "#cc0808", "#cc0808", "#f85761", "#f85761")
    DECLARE_QGC_COLOR(button,               "#e4eaf3", "#ffffff", "#1a2330", "#202c3f")
    DECLARE_QGC_COLOR(buttonBorder,         "#bcc9da", "#9baec8", "#2c3a50", "#3a4f6b")
    DECLARE_QGC_COLOR(buttonText,           "#7a8797", "#18253a", "#7989a0", "#dbe7f7")
    DECLARE_QGC_COLOR(buttonHighlight,      "#dceaff", "#dceaff", "#24364e", "#285489")
    DECLARE_QGC_COLOR(buttonHighlightText,  "#58708f", "#153c70", "#a0b6d0", "#f3f7ff")
    DECLARE_QGC_COLOR(primaryButton,        "#9fb4d0", "#2b71ca", "#2c3c55", "#4a9eff")
    DECLARE_QGC_COLOR(primaryButtonText,    "#edf3fc", "#ffffff", "#a0b6d0", "#0b1523")
    DECLARE_QGC_COLOR(textField,            "#edf1f7", "#ffffff", "#1a2330", "#182438")
    DECLARE_QGC_COLOR(textFieldText,        "#7a8797", "#18253a", "#7989a0", "#e9eff8")
    DECLARE_QGC_COLOR(mapButton,            "#585858", "#333333", "#585858", "#000000")
    DECLARE_QGC_COLOR(mapButtonHighlight,   "#585858", "#f47a1f", "#585858", "#ff8a1f")
    DECLARE_QGC_COLOR(mapIndicator,         "#585858", "#f47a1f", "#585858", "#ff8a1f")
    DECLARE_QGC_COLOR(mapIndicatorChild,    "#585858", "#766043", "#585858", "#766043")
    DECLARE_QGC_COLOR(colorGreen,           "#008f2d", "#008f2d", "#00e04b", "#00e04b")
    DECLARE_QGC_COLOR(colorYellow,          "#a2a200", "#a2a200", "#ffff00", "#ffff00")
    DECLARE_QGC_COLOR(colorYellowGreen,     "#799f26", "#799f26", "#9dbe2f", "#9dbe2f")
    DECLARE_QGC_COLOR(colorOrange,          "#bf7539", "#bf7539", "#de8500", "#de8500")
    DECLARE_QGC_COLOR(colorRed,             "#b52b2b", "#b52b2b", "#f32836", "#f32836")
    DECLARE_QGC_COLOR(colorGrey,            "#808080", "#808080", "#bfbfbf", "#bfbfbf")
    DECLARE_QGC_COLOR(colorBlue,            "#1a72ff", "#1a72ff", "#536dff", "#536dff")
    DECLARE_QGC_COLOR(alertBackground,      "#eecc44", "#eecc44", "#eecc44", "#eecc44")
    DECLARE_QGC_COLOR(alertBorder,          "#808080", "#808080", "#808080", "#808080")
    DECLARE_QGC_COLOR(alertText,            "#000000", "#000000", "#000000", "#000000")
    DECLARE_QGC_COLOR(missionItemEditor,    "#585858", "#dbfef8", "#585858", "#585d83")
    DECLARE_QGC_COLOR(toolStripHoverColor,  "#585858", "#9D9D9D", "#585858", "#585d83")
    DECLARE_QGC_COLOR(statusFailedText,     "#9d9d9d", "#000000", "#707070", "#ffffff")
    DECLARE_QGC_COLOR(statusPassedText,     "#9d9d9d", "#000000", "#707070", "#ffffff")
    DECLARE_QGC_COLOR(statusPendingText,    "#9d9d9d", "#000000", "#707070", "#ffffff")
    DECLARE_QGC_COLOR(toolbarBackground,    "#edf5f7fb", "#edf5f7fb", "#ed10151f", "#ed10151f")
    DECLARE_QGC_COLOR(groupBorder,          "#cbd5e3", "#cbd5e3", "#2d3b50", "#2d3b50")
    DECLARE_QGC_COLOR(modifiedParamValue,   "#bf7539", "#bf7539", "#de8500", "#de8500")

    // Colors not affecting by theming
    //                                                      Disabled     Enabled
    DECLARE_QGC_NONTHEMED_COLOR(brandingPurple,             "#203b5d", "#203b5d")
    DECLARE_QGC_NONTHEMED_COLOR(brandingBlue,               "#6b8296", "#4a9eff")
    DECLARE_QGC_NONTHEMED_COLOR(toolStripFGColor,           "#707070", "#ffffff")
    DECLARE_QGC_NONTHEMED_COLOR(photoCaptureButtonColor,    "#707070", "#ffffff")
    DECLARE_QGC_NONTHEMED_COLOR(videoCaptureButtonColor,    "#f89a9e", "#f32836")

    // Colors not affecting by theming or enable/disable
    DECLARE_QGC_SINGLE_COLOR(mapWidgetBorderLight,          "#ffffff")
    DECLARE_QGC_SINGLE_COLOR(mapWidgetBorderDark,           "#000000")
    DECLARE_QGC_SINGLE_COLOR(mapMissionTrajectory,          "#be781c")
    DECLARE_QGC_SINGLE_COLOR(planMissionTrajectory,         "#f5c66f")
    DECLARE_QGC_SINGLE_COLOR(planWaypoint,                  "#ffd078")
    DECLARE_QGC_SINGLE_COLOR(planWaypointSelected,          "#65e6f5")
    DECLARE_QGC_SINGLE_COLOR(planWaypointOutline,           "#102b41")
    DECLARE_QGC_SINGLE_COLOR(planTakeoff,                   "#62e0b5")
    DECLARE_QGC_SINGLE_COLOR(planHome,                      "#8fb8e8")
    DECLARE_QGC_SINGLE_COLOR(surveyPolygonInterior,         "green")
    DECLARE_QGC_SINGLE_COLOR(surveyPolygonTerrainCollision, "red")

}

void QGCPalette::setColorGroupEnabled(bool enabled)
{
    _colorGroupEnabled = enabled;
    emit paletteChanged();
}

void QGCPalette::setGlobalTheme(Theme newTheme)
{
    // Mobile build does not have themes
    if (_theme != newTheme) {
        _theme = newTheme;
        _signalPaletteChangeToAll();
    }
}

void QGCPalette::_signalPaletteChangeToAll()
{
    // Notify all objects of the new theme
    for (QGCPalette *palette : std::as_const(_paletteObjects)) {
        palette->_signalPaletteChanged();
    }
}

void QGCPalette::_signalPaletteChanged()
{
    emit paletteChanged();
}
