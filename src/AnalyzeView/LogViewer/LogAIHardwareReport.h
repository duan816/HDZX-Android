#pragma once
#include "LogParseResultPrivate.h"
#include <algorithm>
#include <cmath>

namespace LogAIHardwareReport {
inline QVariantMap statistics(const LogParseResult &log, const QStringList &names, double scale, const QString &unit)
{
    for (const auto &name : names) {
        const auto samples = log.fieldSamples.value(name);
        double sum = 0, low = INFINITY, high = -INFINITY, peakTime = 0;
        int count = 0;
        for (const auto &sample : samples) {
            if (!std::isfinite(sample.y())) continue;
            const double value = sample.y() * scale;
            sum += value; ++count; low = std::min(low, value);
            if (value > high) { high = value; peakTime = sample.x(); }
        }
        if (count) return {{"field", name}, {"unit", unit}, {"samples", count}, {"min", low},
            {"max", high}, {"mean", sum/count}, {"peak_seconds", peakTime}};
    }
    return {{"field", ""}, {"unit", unit}, {"samples", 0}, {"min", QVariant()}, {"max", QVariant()}, {"mean", QVariant()}};
}
inline QVariantMap build(const LogParseResult &log)
{
    const bool ap = log.sourceType == LogParseResult::SourceType::APMDataFlash;
    const auto cpu = statistics(log, ap ? QStringList{"PM.Load"} : QStringList{"cpuload.load", "cpuload_0.load"}, ap ? 0.1 : 100.0, "%");
    const auto memory = statistics(log, ap ? QStringList{"PM.Mem"} : QStringList{"cpuload.ram_usage", "cpuload_0.ram_usage"}, ap ? 1.0 : 100.0, ap ? "bytes free" : "% used");
    QVariantList imu;
    for (const auto &name : log.fieldSamples.keys()) {
        if (!(name.startsWith("IMU") && name.endsWith(".GyrX")) && !(name.startsWith("sensor_gyro") && name.endsWith(".x"))) continue;
        const auto samples = log.fieldSamples.value(name);
        if (samples.size() < 2 || samples.last().x() <= samples.first().x()) continue;
        const double rate = (samples.size()-1)/(samples.last().x()-samples.first().x());
        imu.append(QVariantMap{{"field", name}, {"logged_rate_hz", rate}, {"nyquist_reference_hz", rate/2}, {"scope", "全日志平均，含间隙；并非物理IMU采样率，实例可能合并"}});
    }
    return {{"cpu_load", cpu}, {"memory", memory},
        {"loop_max_us", statistics(log, {"PM.MaxT"}, 1, "us")},
        {"loop_rate_hz", statistics(log, {"PM.LR"}, 1, "Hz")},
        {"internal_errors", statistics(log, {"PM.IntE", "PM.InE", "MON.IErr"}, 1, "bitmask")},
        {"imu_clipping", statistics(log, {"VIBE.Clip", "VIBE.Clip0", "vehicle_imu_status.accel_clipping[0]"}, 1, "count")},
        {"imu_logging", imu}, {"watchdog_logged", log.fieldSamples.contains("WDOG.Tsk")},
        {"scope", "硬件诊断使用全日志，保留地面碰触/冲击。没有字段显示未知，不把0条事件解释为硬件正常。"}};
}
}
