#pragma once
#include "LogParseResultPrivate.h"
#include <QtCore/QVariantMap>
namespace LogAITuningMetrics {
QVariantMap build(const LogParseResult &log, const CancelToken &cancel = nullptr);
}
