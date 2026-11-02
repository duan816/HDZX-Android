#pragma once

#include "LogParseResultPrivate.h"

namespace LogAssessment {
/// Read-only, bounded report generation. Missing telemetry never means healthy hardware.
QVariantList evaluate(const LogParseResult& log, const CancelToken& cancel = nullptr);
}  // namespace LogAssessment
