#pragma once

#include <QtCore/QString>
#include <QtCore/QHash>

namespace FlightModePresentation {
struct Mode { QString english; QString chinese; };
inline Mode resolve(QString mode)
{
    mode = mode.simplified().toLower();
    mode.remove(' '); mode.remove('_'); mode.remove('-');
    static const QHash<QString, Mode> modes = {
        {"stabilize", {"Stabilize", "自稳模式"}}, {"stabilized", {"Stabilized", "自稳模式"}},
        {"althold", {"AltHold", "定高模式"}}, {"altitudehold", {"AltHold", "定高模式"}},
        {"altitude", {"Altitude", "定高模式"}}, {"loiter", {"Loiter", "定点模式"}},
        {"poshold", {"PosHold", "位置保持"}}, {"positionhold", {"PosHold", "位置保持"}},
        {"position", {"Position", "定点模式"}}, {"hold", {"Hold", "悬停模式"}},
        {"manual", {"Manual", "手动模式"}}, {"acro", {"Acro", "特技模式"}},
        {"offboard", {"Offboard", "外部控制模式"}}, {"guided", {"Guided", "引导模式"}},
        {"auto", {"Auto", "自动模式"}}, {"mission", {"Mission", "任务模式"}},
        {"rtl", {"RTL", "返航模式"}}, {"return", {"Return", "返航模式"}},
        {"land", {"Land", "降落模式"}}, {"takeoff", {"Takeoff", "起飞模式"}},
        {"circle", {"Circle", "绕圈模式"}}, {"autotune", {"AutoTune", "自动调参模式"}},
        {"brake", {"Brake", "刹停模式"}}, {"smartrtl", {"SmartRTL", "智能返航模式"}},
        {"follow", {"Follow", "跟随模式"}}, {"followme", {"Follow", "跟随模式"}},
        {"flowhold", {"FlowHold", "光流悬停模式"}}, {"guidednogps", {"GuidedNoGPS", "无卫星引导模式"}},
        {"drift", {"Drift", "漂移模式"}}, {"sport", {"Sport", "运动模式"}},
        {"throw", {"Throw", "抛飞模式"}}, {"zigzag", {"ZigZag", "折线模式"}},
        {"systemid", {"SystemID", "系统辨识模式"}}, {"autortl", {"AutoRTL", "自动任务返航模式"}},
        {"orbit", {"Orbit", "环绕模式"}}, {"descend", {"Descend", "下降模式"}},
        {"precisionland", {"PrecisionLand", "精准降落模式"}}
    };
    return modes.value(mode);
}
inline QString speech(const QString &mode)
{
    const auto value = resolve(mode);
    return value.english.isEmpty() ? QStringLiteral("Flight mode，飞行模式已切换，请查看当前模式。")
                                  : value.english + QStringLiteral("，") + value.chinese + QStringLiteral("。");
}
inline QString label(const QString &mode)
{
    const auto value = resolve(mode);
    return value.english.isEmpty() ? mode : value.chinese + QStringLiteral("（") + value.english + QStringLiteral("）");
}
}
