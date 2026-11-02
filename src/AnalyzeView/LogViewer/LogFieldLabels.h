#pragma once

#include <QtCore/QString>

namespace LogFieldLabels {
QString groupLabel(const QString& group);
QString fieldLabel(const QString& field, bool includeGroup = false);
QString errorDescription(int subsystem, int code);
}  // namespace LogFieldLabels
