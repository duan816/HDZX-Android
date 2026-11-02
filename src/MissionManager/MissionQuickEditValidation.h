#pragma once

#include <cmath>

#include <QtCore/QObject>
#include <QtCore/QtNumeric>

#include "MissionCommandUIInfo.h"

namespace MissionQuickEditValidation {

inline QString parseValue(const QString& text, const MissionCmdParamInfo& info, double& value)
{
    const QString input = text.trimmed();
    if (input.compare(QStringLiteral("nan"), Qt::CaseInsensitive) == 0 && info.nanUnchanged()) {
        value = qQNaN();
        return {};
    }
    bool converted = false;
    value = input.toDouble(&converted);
    if (!converted || !qIsFinite(value)) {
        return QObject::tr("请输入有效数值（Invalid number）");
    }
    if (value < info.min() || value > info.max()) {
        return QObject::tr("数值超出允许范围（Out of range）");
    }
    if (!info.enumValues().isEmpty() && !info.enumValues().contains(QVariant(value))) {
        return QObject::tr("请选择列表内的选项（Invalid option）");
    }
    return {};
}

inline bool validArduPilotTurns(double value)
{
    return qIsFinite(value) && value >= 0 && (value <= 1 || std::floor(value) == value);
}

} // namespace MissionQuickEditValidation
