#pragma once

#include <QtCore/QVariantMap>
#include "LogParseResultPrivate.h"

namespace LogAIEvidence {
QVariantMap build(const LogParseResult &log, const CancelToken &cancel = nullptr);
}
