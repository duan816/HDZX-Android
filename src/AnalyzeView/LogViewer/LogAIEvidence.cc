#include "LogAIEvidence.h"
#include "LogAITuningMetrics.h"
#include "LogAIHardwareReport.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <limits>

namespace {
bool relevant(const QString &field)
{
    const QStringList groups = {QStringLiteral("ATT."), QStringLiteral("RATE."), QStringLiteral("PIDR."),
        QStringLiteral("PIDP."), QStringLiteral("PIDY."), QStringLiteral("VIBE."), QStringLiteral("RCOU."),
        QStringLiteral("BAT."), QStringLiteral("CTUN."), QStringLiteral("vehicle_angular_velocity."),
        QStringLiteral("vehicle_rates_setpoint."), QStringLiteral("rate_ctrl_status."),
        QStringLiteral("vehicle_imu_status."), QStringLiteral("actuator_motors."), QStringLiteral("battery_status.")};
    if (field.endsWith(QStringLiteral("TimeUS")) || field.contains(QStringLiteral("timestamp"))) return false;
    if (field.startsWith(QStringLiteral("GPS."))) {
        return QStringList{QStringLiteral("GPS.Status"), QStringLiteral("GPS.NSats"), QStringLiteral("GPS.HDop"), QStringLiteral("GPS.Spd")}.contains(field);
    }
    if (field.startsWith(QStringLiteral("XKF4.")) || field.startsWith(QStringLiteral("NKF4."))) {
        // Include estimator health and variance, exclude local origin offsets.
        return QStringList{QStringLiteral("C"), QStringLiteral("SV"), QStringLiteral("SP"), QStringLiteral("SH"),
            QStringLiteral("SM"), QStringLiteral("FS"), QStringLiteral("TS"), QStringLiteral("SS"),
            QStringLiteral("GPS"), QStringLiteral("PI")}.contains(field.section('.', 1));
    }
    return std::any_of(groups.cbegin(), groups.cend(), [&field](const auto &group) { return field.startsWith(group); });
}
bool tuningParameter(const QString &name)
{
    const QStringList prefixes = {QStringLiteral("ATC_ANG_"), QStringLiteral("ATC_RAT_"), QStringLiteral("INS_GYRO_"),
        QStringLiteral("INS_ACCEL_"), QStringLiteral("MC_ROLL"), QStringLiteral("MC_PITCH"), QStringLiteral("MC_YAW"),
        QStringLiteral("IMU_GYRO_"), QStringLiteral("IMU_ACCEL_")};
    return std::any_of(prefixes.cbegin(), prefixes.cend(), [&name](const auto &prefix) { return name.startsWith(prefix); });
}
}

QVariantMap LogAIEvidence::build(const LogParseResult &log, const CancelToken &cancel)
{
    QVariantMap result{{QStringLiteral("format"), log.sourceType == LogParseResult::SourceType::APMDataFlash
        ? QStringLiteral("ArduPilot DataFlash") : log.sourceType == LogParseResult::SourceType::PX4ULog
        ? QStringLiteral("PX4 ULog") : QStringLiteral("unknown")},
        {QStringLiteral("start_seconds"), log.minTimestamp}, {QStringLiteral("end_seconds"), log.maxTimestamp},
        {QStringLiteral("decoded_record_count"), log.sampleCount},
        {QStringLiteral("limits"), QStringLiteral("本地解码摘要，不是原始完整日志；字段数上限96，每类上限8，按原始字段全样本统计，8个时间窗保留极值。未知单位必须核对官方日志定义，不能混用AP/PX4单位。同名多实例字段可能合并，不能假定对应某个IMU。未上传GPS位置、硬件标识或原始MSG文本。日志参数不等于当前飞控参数。")}};
    QVariantList fields;
    auto names = log.fieldSamples.keys();
    std::sort(names.begin(), names.end(), [](const QString &a, const QString &b) {
        const QStringList priority = {QStringLiteral("ATT."), QStringLiteral("RATE."), QStringLiteral("PIDR."),
            QStringLiteral("PIDP."), QStringLiteral("PIDY."), QStringLiteral("VIBE.")};
        auto rank = [&priority](const QString &name) {
            for (int i = 0; i < priority.size(); ++i) if (name.startsWith(priority[i])) return i;
            return 10;
        };
        const int ar = rank(a), br = rank(b);
        if (ar != br) return ar < br;
        const QStringList preferred = {QStringLiteral("ATT.DesRoll"), QStringLiteral("ATT.Roll"),
            QStringLiteral("ATT.DesPitch"), QStringLiteral("ATT.Pitch"), QStringLiteral("ATT.DesYaw"), QStringLiteral("ATT.Yaw"),
            QStringLiteral("RATE.RDes"), QStringLiteral("RATE.R"), QStringLiteral("RATE.PDes"), QStringLiteral("RATE.P"),
            QStringLiteral("RATE.YDes"), QStringLiteral("RATE.Y")};
        const int ai = preferred.indexOf(a), bi = preferred.indexOf(b);
        if (ai >= 0 || bi >= 0) return (ai < 0 ? 99 : ai) < (bi < 0 ? 99 : bi);
        return a < b;
    });
    QHash<QString, int> perGroup;
    for (const auto &name : names) {
        if (cancel && cancel->load(std::memory_order_relaxed)) return {};
        const QString group = name.section('.', 0, 0);
        if (!relevant(name) || fields.size() >= 96 || perGroup.value(group) >= 8) continue;
        const auto &points = log.fieldSamples[name];
        double minimum = std::numeric_limits<double>::infinity(), maximum = -minimum;
        double sum = 0;
        int count = 0;
        std::array<double, 8> low, high;
        low.fill(minimum); high.fill(maximum);
        const double duration = std::max(0.001, log.maxTimestamp - log.minTimestamp);
        for (const auto &point : points) {
            if (!std::isfinite(point.x()) || !std::isfinite(point.y())) continue;
            if ((count % 4096 == 0) && cancel && cancel->load(std::memory_order_relaxed)) return {};
            minimum = std::min(minimum, point.y()); maximum = std::max(maximum, point.y());
            sum += point.y(); ++count;
            const int bucket = std::clamp(static_cast<int>((point.x() - log.minTimestamp) / duration * 8), 0, 7);
            low[bucket] = std::min(low[bucket], point.y()); high[bucket] = std::max(high[bucket], point.y());
        }
        if (count == 0) continue;
        ++perGroup[group];
        QVariantList windows;
        for (int i = 0; i < 8; ++i) if (std::isfinite(low[i]) && std::isfinite(high[i])) {
            windows.append(QVariantMap{{QStringLiteral("start_s"), log.minTimestamp + duration * i / 8},
                {QStringLiteral("end_s"), log.minTimestamp + duration * (i + 1) / 8},
                {QStringLiteral("min"), low[i]}, {QStringLiteral("max"), high[i]}});
        }
        QString unit = QStringLiteral("unknown");
        if (name.startsWith(QStringLiteral("RATE.")) && QStringList{"R", "RDes", "P", "PDes", "Y", "YDes"}.contains(name.section('.', 1))) unit = QStringLiteral("deg/s");
        if (name == QStringLiteral("RATE.A") || name == QStringLiteral("RATE.ADes")) unit = QStringLiteral("cm/s^2 (vertical acceleration, NOT angular rate)");
        if (name.startsWith(QStringLiteral("VIBE.Vibe"))) unit = QStringLiteral("m/s^2 (NOT g)");
        if (name.startsWith(QStringLiteral("ATT.")) && QStringList{"Roll", "Pitch", "Yaw", "DesRoll", "DesPitch", "DesYaw"}.contains(name.section('.', 1))) unit = QStringLiteral("deg");
        fields.append(QVariantMap{{QStringLiteral("field"), name}, {QStringLiteral("unit"), unit}, {QStringLiteral("samples"), count},
            {QStringLiteral("min"), minimum}, {QStringLiteral("max"), maximum},
            {QStringLiteral("mean"), sum / count}, {QStringLiteral("window_extrema"), windows}});
    }
    result.insert(QStringLiteral("field_statistics"), fields);
    result.insert("hardware_report", LogAIHardwareReport::build(log));
    QVariantList parameters;
    QVariantMap latestParameters;
    for (const auto &item : log.parameters) {
        const auto parameter = item.toMap();
        const QString name = parameter.value(QStringLiteral("name")).toString();
        if (tuningParameter(name)) latestParameters.insert(name, parameter.value(QStringLiteral("value")));
    }
    for (auto it = latestParameters.cbegin(); it != latestParameters.cend() && parameters.size() < 80; ++it) {
        parameters.append(QVariantMap{{QStringLiteral("name"), it.key()}, {QStringLiteral("value"), it.value()}});
    }
    result.insert(QStringLiteral("log_parameters"), parameters);
    QVariantMap filterReference;
    for (const auto &item : log.parameters) {
        const auto parameter = item.toMap();
        const QString name = parameter.value("name").toString();
        if (name.startsWith("INS_HNTCH_") || name.startsWith("INS_HNTC2_"))
            filterReference.insert(name, parameter.value("value"));
    }
    result.insert(QStringLiteral("filter_reference_parameters"), filterReference);
    result.insert(QStringLiteral("parameter_scope"), QStringLiteral("日志内各调参参数的最后一次记录，不等于当前飞机参数或完整参数变化历史"));
    QVariantList modes;
    for (const auto &item : log.modeSegments) { if (modes.size() < 30) modes.append(item); }
    result.insert(QStringLiteral("mode_segments"), modes);
    result.insert(QStringLiteral("event_count"), log.events.size());
    QVariantList events;
    for (const auto &event : log.events) { if (events.size() < 80) events.append(event); }
    result.insert(QStringLiteral("events"), events);
    result.insert(QStringLiteral("dropout_count"), log.sourceType == LogParseResult::SourceType::PX4ULog ? QVariant(log.dropouts.size()) : QVariant());
    result.insert(QStringLiteral("dropout_scope"), QStringLiteral("仅PX4 ULog显式掉数事件；AP未知，不能将事件数0说成未丢记录"));
    QStringList missing;
    for (const QString &group : {QStringLiteral("ATT."), QStringLiteral("RATE."), QStringLiteral("VIBE.")}) {
        if (log.sourceType == LogParseResult::SourceType::APMDataFlash
            && std::none_of(names.cbegin(), names.cend(), [&group](const auto &name) { return name.startsWith(group); })) missing.append(group);
    }
    result.insert(QStringLiteral("missing_expected_groups"), missing);
    const auto metrics = LogAITuningMetrics::build(log, cancel);
    if (cancel && cancel->load(std::memory_order_relaxed)) return {};
    for (auto it = metrics.cbegin(); it != metrics.cend(); ++it) result.insert(it.key(), it.value());
    return result;
}
