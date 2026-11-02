#include "LogAITuningMetrics.h"
#include "LogAIRateAnalysis.h"
#include <QtCore/QRegularExpression>
#include <array>
#include <algorithm>
#include <cmath>
#include <numbers>

namespace {
QString firstField(const LogParseResult &log, const QStringList &names)
{
    for (const auto &name : names) if (log.fieldSamples.contains(name)) return name;
    return {};
}
bool canceled(const CancelToken &cancel) { return cancel && cancel->load(std::memory_order_relaxed); }
}

QVariantMap LogAITuningMetrics::build(const LogParseResult &log, const CancelToken &cancel)
{
    QVariantMap identity{{"vehicle_type", log.detectedVehicleType}, {"firmware", QString()}, {"board", QString()}};
    static const QRegularExpression version(QStringLiteral("\\b(ArduCopter|ArduPlane|ArduRover|ArduSub|PX4)\\s+[Vv]?([0-9]+\\.[0-9]+\\.[0-9]+(?:[-a-zA-Z0-9.]*)?)"));
    static const QRegularExpression board(QStringLiteral("^(CUAV[-A-Za-z0-9]*|Cube[-A-Za-z0-9]*|Pixhawk[-A-Za-z0-9]*|Pixracer|Durandal|Kakute[-A-Za-z0-9]*|Matek[-A-Za-z0-9]*|fmuv[0-9]+)\\b"), QRegularExpression::CaseInsensitiveOption);
    for (const auto &item : log.messages) {
        if (canceled(cancel)) return {};
        const auto text = item.toMap().value("text").toString().left(512);
        const auto match = version.match(text);
        if (match.hasMatch()) identity["firmware"] = match.captured(1) + " " + match.captured(2);
        const auto hardware = board.match(text);
        if (hardware.hasMatch()) identity["board"] = hardware.captured(1);
    }
    if (identity["firmware"].toString().isEmpty() && !log.firmwareVersion.isEmpty()) identity["firmware"] = log.firmwareVersion;
    if (!log.boardName.isEmpty()) identity["board"] = log.boardName;
    QVariantList axes, pid;
    quint64 activeTotal = 0, qualifiedTotal = 0;
    double scoreSum = 0;
    int scoredAxes = 0;
    const bool ap = log.sourceType == LogParseResult::SourceType::APMDataFlash;
    const double baseFloor = ap ? 5.0 : 5.0 * std::numbers::pi / 180.0;
    const std::array<QString, 3> labels{"roll", "pitch", "yaw"};
    const std::array<QString, 3> apNames{"R", "P", "Y"};
    for (int axis = 0; axis < 3; ++axis) {
        QString actualName = firstField(log, {"RATE." + apNames[axis],
            QString("vehicle_angular_velocity.xyz[%1]").arg(axis), QString("vehicle_angular_velocity_0.xyz[%1]").arg(axis)});
        QString desiredName = firstField(log, {"RATE." + apNames[axis] + "Des",
            "vehicle_rates_setpoint." + labels[axis], "vehicle_rates_setpoint_0." + labels[axis]});
        // PID Tar is the controller's internal target, not RATE.*Des. Never
        // combine one member from each pair: Copter PID values use radians.
        const QString pidActual = "PID" + apNames[axis] + ".Act";
        const QString pidTarget = "PID" + apNames[axis] + ".Tar";
        const bool pidSource = ap && (actualName.isEmpty() || desiredName.isEmpty())
            && log.fieldSamples.contains(pidActual) && log.fieldSamples.contains(pidTarget);
        if (pidSource) { actualName = pidActual; desiredName = pidTarget; }
        const bool copterPid = pidSource && identity.value("firmware").toString().startsWith("ArduCopter");
        double floor = copterPid ? 5.0 * std::numbers::pi / 180.0 : baseFloor;
        if (pidSource && !copterPid) {
            double peak = 0;
            for (const auto &sample : log.fieldSamples.value(desiredName))
                if (std::isfinite(sample.y())) peak = std::max(peak, std::abs(sample.y()));
            floor = std::max(1e-6, peak * 0.05);
        }
        auto actual = log.fieldSamples.value(actualName), desired = log.fieldSamples.value(desiredName);
        const auto chronological = [](const QPointF &a, const QPointF &b) {
            if (!std::isfinite(a.x())) return false;
            if (!std::isfinite(b.x())) return true;
            return a.x() < b.x();
        };
        if (!std::is_sorted(actual.cbegin(), actual.cend(), chronological)) std::stable_sort(actual.begin(), actual.end(), chronological);
        if (!std::is_sorted(desired.cbegin(), desired.cend(), chronological)) std::stable_sort(desired.begin(), desired.end(), chronological);
        QVariantMap metric{{"axis", labels[axis]}, {"actual_field", actualName}, {"target_field", desiredName},
            {"unit", pidSource ? (copterPid ? "rad/s" : "日志原单位（待核实）") : ap ? "deg/s" : "rad/s"}, {"matching_max_gap_s", 0.05},
            {"source_basis", pidSource ? "PID控制器内部Tar/Act；目标可能已经滤波，不能与RATE目标混用。非Copter或未知版本保留原单位，激励阈值取目标峰值5%，只做相对响应参考。" : "RATE / vehicle_rates_setpoint 目标与实际"},
            {"active_command_threshold", floor}, {"tolerance_floor", floor}, {"tolerance_fraction", 0.20}};
        int cursor = 0, pairs = 0, active = 0, qualified = 0;
        QVector<LogAIRateAnalysis::Pair> temporalPairs;
        const QString armedField = firstField(log, {"ARM.ArmState", "vehicle_status.arming_state", "vehicle_status_0.arming_state"});
        const QString landedField = firstField(log, {"vehicle_land_detected.landed", "vehicle_land_detected_0.landed"});
        const auto armedStates = log.fieldSamples.value(armedField);
        const auto landedStates = log.fieldSamples.value(landedField);
        const auto heights = log.fieldSamples.value(ap ? "CTUN.Alt" : "vehicle_local_position.z");
        int heightCursor = 0;
        int armedCursor = 0, landedCursor = 0;
        int excluded = 0;
        double errorSquared = 0, activeErrorSquared = 0, targetSquared = 0, actualSquared = 0;
        double scoreBegin = NAN, scoreEnd = NAN;
        for (int i = 0; i < actual.size() && !desired.isEmpty(); ++i) {
            if (i % 4096 == 0 && canceled(cancel)) return {};
            const auto &point = actual[i];
            if (!std::isfinite(point.x())) continue;
            while (cursor + 1 < desired.size() && std::abs(desired[cursor + 1].x() - point.x()) <= std::abs(desired[cursor].x() - point.x())) ++cursor;
            const auto &target = desired[cursor];
            if (!std::isfinite(target.x()) || !std::isfinite(point.y()) || !std::isfinite(target.y()) || std::abs(target.x() - point.x()) > 0.05) continue;
            auto stateAt = [](const auto &states, int &index, double time) -> double {
                if (states.isEmpty() || states.first().x() > time) return NAN;
                while (index + 1 < states.size() && states[index + 1].x() <= time) ++index;
                return states[index].y();
            };
            const double armed = stateAt(armedStates, armedCursor, point.x());
            const double landed = stateAt(landedStates, landedCursor, point.x());
            const double height = stateAt(heights, heightCursor, point.x());
            bool manualExcluded = false;
            for (const auto &item : log.analysisSettings.value("exclusions").toList()) {
                const auto range = item.toMap();
                if (point.x() >= range.value("begin").toDouble() && point.x() <= range.value("end").toDouble()) manualExcluded = true;
            }
            const bool inWindow = !log.analysisSettings.contains("begin") ||
                (point.x() >= log.analysisSettings.value("begin").toDouble() && point.x() <= log.analysisSettings.value("end").toDouble());
            // Height is only a ground-screening proxy when an actual land detector is absent.
            // Unknown remains unknown; do not reject anomalies in the hardware report.
            const bool likelyGround = landedStates.isEmpty() && std::isfinite(height) && std::abs(height) < 0.5;
            // State fields are held between actual reports, never inferred from commands.
            if ((armedStates.isEmpty() || (ap ? armed == 1 : armed == 2))
                && (landedStates.isEmpty() || landed == 0) && !likelyGround && !manualExcluded && inWindow) {
                temporalPairs.append({point.x(), target.y(), point.y()});
            } else { ++excluded; continue; }
            ++pairs;
            const double error = point.y() - target.y();
            errorSquared += error * error;
            if (std::abs(target.y()) >= floor) {
                ++active;
                activeErrorSquared += error * error;
                if (!std::isfinite(scoreBegin)) scoreBegin = point.x();
                scoreEnd = point.x();
                if (std::abs(error) <= std::max(floor, 0.20 * std::abs(target.y()))) ++qualified;
                targetSquared += target.y() * target.y();
                actualSquared += point.y() * point.y();
            }
        }
        metric["paired_samples"] = pairs;
        auto temporal = LogAIRateAnalysis::analyze(temporalPairs, floor);
        temporal["armed_field"] = armedField;
        temporal["landed_field"] = landedField;
        temporal["excluded_pair_count"] = excluded;
        temporal["ground_proxy_field"] = landedStates.isEmpty() ? (ap ? "CTUN.Alt" : "vehicle_local_position.z") : "";
        temporal["ground_exclusion_limit"] = "只依据报告的解锁/着陆、离地高度代理和用户指定区间排除。不能可靠识别空中触碰；不自动删掉振荡/冲击峰，故障报告保留全日志证据。";
        QStringList enhancementsMissing;
        if (pidSource && !copterPid) enhancementsMissing.append("PID字段单位/固件需核实");
        if (ap && !log.fieldSamples.contains("PID" + apNames[axis] + ".P")) enhancementsMissing.append("PID分解");
        if (ap && !log.fieldSamples.contains("VIBE.VibeX")) enhancementsMissing.append("VIBE振动");
        if (!ap && !log.fieldSamples.contains("vehicle_imu_status.accel_vibration_metric")) enhancementsMissing.append("IMU振动指标");
        temporal["missing_enhancements"] = enhancementsMissing;
        temporal["scope"] = !armedField.isEmpty() && !landedField.isEmpty()
            ? QStringLiteral("已报告解锁且非着陆的最长连续匹配段；最多65536个原采样间隔点")
            : !armedField.isEmpty() ? QStringLiteral("已报告解锁的最长连续匹配段；缺少着陆状态，不能保证全为空中数据；最多65536点")
            : QStringLiteral("未报告解锁/着陆状态：最长连续匹配段，不能保证全为空中数据；最多65536点");
        metric["temporal_analysis"] = temporal;
        metric["active_samples"] = active;
        metric["rmse"] = pairs ? QVariant(std::sqrt(errorSquared / pairs)) : QVariant();
        metric["tracking_percent"] = active ? QVariant(100.0 * qualified / active) : QVariant();
        // No delay compensation: lag, amplitude loss, overshoot and noise remain real errors.
        const double normalizedError = targetSquared > 0 ? std::sqrt(activeErrorSquared / targetSquared) : NAN;
        const double score = std::isfinite(normalizedError) ? 100.0 * std::clamp(1.0 - normalizedError, 0.0, 1.0) : NAN;
        metric["tracking_score"] = std::isfinite(score) ? QVariant(score) : QVariant();
        metric["active_rmse"] = active ? QVariant(std::sqrt(activeErrorSquared / active)) : QVariant();
        metric["active_target_rms"] = active ? QVariant(std::sqrt(targetSquared / active)) : QVariant();
        metric["normalized_tracking_error"] = std::isfinite(normalizedError) ? QVariant(normalizedError) : QVariant();
        metric["score_start_seconds"] = std::isfinite(scoreBegin) ? QVariant(scoreBegin) : QVariant();
        metric["score_end_seconds"] = std::isfinite(scoreEnd) ? QVariant(scoreEnd) : QVariant();
        if (std::isfinite(score)) { scoreSum += score; ++scoredAxes; }
        metric["rms_amplitude_ratio"] = targetSquared > 0 ? QVariant(std::sqrt(actualSquared / targetSquared)) : QVariant();
        metric["average_logged_rate_hz"] = actual.size() > 1 && actual.last().x() > actual.first().x()
            ? QVariant((actual.size() - 1) / (actual.last().x() - actual.first().x())) : QVariant();
        axes.append(metric);
        activeTotal += active; qualifiedTotal += qualified;
        if (ap) {
            QVariantMap contribution{{"axis", labels[axis]}, {"scope", "最长有效跟踪窗口，与地面/碰触排除一致"}};
            double total = 0;
            std::array<double, 3> means{};
            for (int term = 0; term < 3; ++term) {
                const QString field = "PID" + apNames[axis] + "." + std::array<QString, 3>{"P", "I", "D"}[term];
                const auto samples = log.fieldSamples.value(field);
                double sum = 0; int count = 0;
                for (int i = 0; i < samples.size(); ++i) {
                    if (i % 4096 == 0 && canceled(cancel)) return {};
                    if (!temporal.contains("start_seconds") || samples[i].x()<temporal.value("start_seconds").toDouble()
                        || samples[i].x()>temporal.value("end_seconds").toDouble()) continue;
                    if (std::isfinite(samples[i].y())) { sum += std::abs(samples[i].y()); ++count; }
                }
                if (count) means[term] = sum / count;
                contribution[std::array<QString, 3>{"p_samples", "i_samples", "d_samples"}[term]] = count;
                total += means[term];
            }
            const bool complete = contribution["p_samples"].toInt() > 0 && contribution["i_samples"].toInt() > 0 && contribution["d_samples"].toInt() > 0 && total > 0;
            for (int term = 0; term < 3; ++term) contribution[std::array<QString, 3>{"p", "i", "d"}[term]] = complete ? QVariant(means[term] / total) : QVariant();
            pid.append(contribution);
        }
    }
    return {{"identity", identity}, {"rate_tracking", axes}, {"pid_contributions", pid},
        {"tracking_score", scoredAxes ? QVariant(scoreSum / scoredAxes) : QVariant()},
        {"tracking_qualified_percent", activeTotal ? QVariant(100.0 * qualifiedTotal / activeTotal) : QVariant()},
        {"tracking_score_axes", scoredAxes}, {"tracking_analysis_window", log.analysisSettings},
        {"tracking_method", QStringLiteral("每轴跟踪评分=100×clamp(1−RMS(实际−目标)/RMS(目标),0,1)，对有有效动作的轴等权平均；保留原始时间，不移动曲线消除滞后。有效区间排除明确未解锁/着陆、低于0.5m高度代理与用户排除段；最近时间匹配≤50ms。RATE激励阈值5deg/s，PX4/Copter PID为等效rad/s；未知固件PID保留原单位，阈值为目标峰值5%，查看逐轴source_basis和active_command_threshold。无有效动作显示未知。原合格样本比例另列tracking_qualified_percent/每轴tracking_percent，误差≤max(逐轴阈值,目标幅值20%)为合格。无状态字段不能保证空中；评分不是AI置信度或安全评级。PID条是最长有效窗口P/I/D平均绝对幅值归一化，不代表控制效能。")}};
}
