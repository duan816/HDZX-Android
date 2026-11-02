#include "LogAssessment.h"

#include <QtCore/QRegularExpression>
#include <algorithm>
#include <cmath>
#include <limits>

#include "LogFieldLabels.h"

namespace {
using Samples = QVector<QPointF>;
const QString apLogs = QStringLiteral("https://ardupilot.org/copter/docs/logmessages.html");
const QString apVibe = QStringLiteral("https://ardupilot.org/copter/docs/common-measuring-vibration.html");
const QString diagnosis =
    QStringLiteral("https://doc.cuav.net/tutorial/copter/log/diagnosing-problems-using-logs.html");
const QString pxAnalysis = QStringLiteral("https://docs.px4.io/main/en/log/flight_log_analysis");
const QString pxEsc = QStringLiteral("https://docs.px4.io/main/en/msg_docs/EscReport");

struct Stats
{
    int count = 0;
    double min = std::numeric_limits<double>::infinity();
    double max = -std::numeric_limits<double>::infinity();
    double longest = 0;
    double firstMatch = -1;
    double increases = 0;
};

Stats stats(const Samples& samples, const std::function<bool(double)>& match = [](double) { return false; })
{
    Stats s;
    double runStart = -1, previousTime = -1, previousValue = -1;
    for (const QPointF& p : samples) {
        if (!std::isfinite(p.x()) || !std::isfinite(p.y()) || p.x() < 0) {
            runStart = -1;
            continue;
        }
        ++s.count;
        s.min = std::min(s.min, p.y());
        s.max = std::max(s.max, p.y());
        if (previousTime >= 0 && p.x() > previousTime && p.y() > previousValue) {
            s.increases += p.y() - previousValue;
        }
        if (match(p.y())) {
            if (s.firstMatch < 0) {
                s.firstMatch = p.x();
            }
            if (runStart < 0 || p.x() <= previousTime || p.x() - previousTime > 1) {
                runStart = p.x();
            }
            s.longest = std::max(s.longest, p.x() - runStart);
        } else {
            runStart = -1;
        }
        previousTime = p.x();
        previousValue = p.y();
    }
    return s;
}

double at(const Samples& samples, double time, double tolerance = 0.1)
{
    const auto it =
        std::lower_bound(samples.cbegin(), samples.cend(), time, [](const QPointF& p, double t) { return p.x() < t; });
    if (it != samples.cend() && std::abs(it->x() - time) <= tolerance) {
        return it->y();
    }
    if (it != samples.cbegin() && std::abs((it - 1)->x() - time) <= tolerance) {
        return (it - 1)->y();
    }
    return std::numeric_limits<double>::quiet_NaN();
}

QString timeText(double time, const LogParseResult& log)
{
    return QStringLiteral("t=%1 s（日志起点后）").arg(std::max(0.0, time - log.minTimestamp), 0, 'f', 2);
}

QVariantMap row(const QString& id, const QString& title, const QString& status, const QString& evidence,
                const QString& advice, const QStringList& fields, const QString& source, double time = -1)
{
    return {{"id", id},         {"title", title},   {"status", status}, {"evidence", evidence},
            {"advice", advice}, {"fields", fields}, {"source", source}, {"time", time}};
}

QStringList matching(const LogParseResult& log, const QString& pattern)
{
    const QRegularExpression re(pattern);
    QStringList fields;
    for (auto it = log.fieldSamples.cbegin(); it != log.fieldSamples.cend(); ++it) {
        if (re.match(it.key()).hasMatch() && !it->isEmpty()) {
            fields.append(it.key());
        }
    }
    fields.sort();
    return fields;
}

QString rangeText(const QString& field, const Stats& s)
{
    return QStringLiteral("%1: %2 ~ %3；有效样本 %4")
        .arg(field)
        .arg(s.min, 0, 'g', 5)
        .arg(s.max, 0, 'g', 5)
        .arg(s.count);
}
}  // namespace

QVariantList LogAssessment::evaluate(const LogParseResult& log, const CancelToken& cancel)
{
    QVariantList report;
    auto stopped = [&]() { return cancel && cancel->load(std::memory_order_relaxed); };
    auto addMissing = [&](const QString& id, const QString& title, const QString& need, const QString& source) {
        report.append(row(id, title, "missing", QStringLiteral("无法评估：") + need,
                          QStringLiteral("请补充相应机载日志；缺少数据不等于没有故障。"), {}, source));
    };
    report.append(row(
        "coverage", "Coverage（评估范围）", "info",
        QStringLiteral("%1 个数值字段；%2 条日志消息；%3 段记录丢失区间。规则版本 HQ-20261003。")
            .arg(log.fieldSamples.size())
            .arg(log.messages.size())
            .arg(log.dropouts.size()),
        QStringLiteral("仅供参考：这是离线规则筛查，不是适航证明或确定故障诊断。未命中规则不代表安全。"
                       "阈值和持续时间是排查参考，需结合机型、飞行阶段与固件版本复核。不会上传日志或修改飞控参数。"),
        {}, pxAnalysis));
    if (!log.dropouts.isEmpty()) {
        report.append(row("dropouts", "Logging（日志记录中断）", "suspect",
                          QStringLiteral("ULog 记录了 %1 段 dropout；此处表示日志记录缺口，不等同于无线链路丢包。")
                              .arg(log.dropouts.size()),
                          QStringLiteral("检查 SD 卡、日志带宽和处理器负载；不要用缺口附近曲线直接判断机械故障。"), {},
                          pxAnalysis));
    }

    const auto vibration = matching(log, "^VIBE(?:\\[\\d+\\])?\\.Vibe[XYZ]$");
    if (vibration.isEmpty()) {
        addMissing("vibration", "Vibration（振动）",
                   "没有 ArduPilot VIBE 字段。PX4 振动指标算法不同，不套用 AP 的 30/60 阈值。", apVibe);
    }
    for (const QString& field : vibration) {
        if (stopped()) {
            return {};
        }
        const auto s = stats(log.fieldSamples[field], [](double v) { return v >= 30; });
        if (!s.count) {
            continue;
        }
        report.append(
            row("vibration-" + field, "Vibration（振动）", s.longest >= 1 ? "suspect" : "info",
                rangeText(field, s) + QStringLiteral("；≥30 m/s² 最长连续 %1 s").arg(s.longest, 0, 'f', 2),
                QStringLiteral("请查看 VibeX/Y/Z 和 Clip0/1/2。持续高振动可能来自桨平衡、轴承、安装或线缆碰撞。"
                               "落地冲击和单次尖峰不直接判为故障；先排除振动再考虑 PID。"),
                {field}, apVibe, s.firstMatch));
    }
    const auto clips = matching(
        log,
        "^(?:VIBE(?:\\[\\d+\\])?\\.Clip[012]|vehicle_imu_status(?:\\[\\d+\\])?\\.(?:accel|gyro)_clipping\\[\\d+\\])$");
    if (clips.isEmpty()) {
        addMissing("clipping", "IMU Clipping（惯性传感器削顶）", "没有削顶计数。", apVibe);
    }
    for (const QString& field : clips) {
        if (stopped()) {
            return {};
        }
        const auto s = stats(log.fieldSamples[field]);
        if (!s.count) {
            continue;
        }
        report.append(row(
            "clip-" + field, "IMU Clipping（惯性传感器削顶）", s.increases > 0 ? "suspect" : "info",
            rangeText(field, s) + QStringLiteral("；本段累计正向增量 %1（计数重置不计入）").arg(s.increases, 0, 'f', 0),
            QStringLiteral("查看计数增长时刻是否发生在起降冲击或正常飞行。正常飞行中持续增长应检查振动与传感器量程。"),
            {field}, apVibe));
    }

    const auto gps = matching(log,
                              "^(?:GPS(?:\\[\\d+\\])?\\.(?:HDop|NSats|Status)|(?:vehicle_gps_position|sensor_gps)(?:\\["
                              "\\d+\\])?\\.(?:hdop|satellites_used|fix_type))$");
    if (gps.isEmpty()) {
        addMissing("gps", "GPS（卫星定位）", "没有 HDop/NSats/Status 或 PX4 对应字段。", diagnosis);
    }
    for (const QString& field : gps) {
        if (stopped()) {
            return {};
        }
        const auto& points = log.fieldSamples[field];
        const bool dop = field.endsWith("HDop") || field.endsWith("hdop");
        const bool fix = field.endsWith("Status") || field.endsWith("fix_type");
        bool priorGoodFix = false, drop = false;
        double onset = -1;
        for (qsizetype i = 0; i < points.size(); ++i) {
            const QPointF& p = points[i];
            if (!std::isfinite(p.y()) || p.y() < 0) {
                continue;
            }
            if (fix) {
                if (p.y() >= 3) {
                    priorGoodFix = true;
                } else if (priorGoodFix) {
                    drop = true;
                    onset = p.x();
                    break;
                }
            } else if (!dop && i > 0) {
                const auto& previous = points[i - 1];
                if (p.x() > previous.x() && p.x() - previous.x() <= 5 && previous.y() >= 6 &&
                    previous.y() - p.y() >= 4) {
                    drop = true;
                    onset = p.x();
                    break;
                }
            }
        }
        const auto s = stats(points, [dop](double v) { return dop && v >= 2 && v < 100; });
        if (!s.count) {
            continue;
        }
        const bool suspect = drop || (dop && s.longest >= 2);
        report.append(row(
            "gps-" + field, "GPS（卫星定位）", suspect ? "suspect" : "info",
            rangeText(field, s) +
                (drop ? QStringLiteral("；发现定位降级或卫星数骤减，") + timeText(onset, log)
                 : dop
                     ? QStringLiteral("；HDOP≥2 最长连续 %1 s（参考筛查，不是硬件故障阈值）").arg(s.longest, 0, 'f', 2)
                     : QString()),
            (suspect ? QStringLiteral("GPS 可能存在异常。")
                     : QStringLiteral("本项未发现上述筛查线索；不代表定位正常。")) +
                QStringLiteral(
                    "请对照 HDop（水平精度因子）、NSats（卫星数）和 Status（定位类型）。"
                    "PX4 对应 hdop、satellites_used、fix_type。比较同一时段的卫星数下降、HDOP 上升及位置跳变；"
                    "也可能是遮挡、多路径或启动搜星，不能据此认定接收机损坏。"),
            gps, diagnosis, onset >= 0 ? onset : s.firstMatch));
    }

    const auto esc = matching(log,
                              "^(?:esc_report(?:\\[\\d+\\])?\\.|esc_status(?:\\[\\d+\\])?\\.esc\\[\\d+\\]\\.)(?:"
                              "failures|esc_failure_flags|esc_errorcount)$");
    if (esc.isEmpty()) {
        addMissing("esc", "ESC / Motor（电调与电机）", "未记录电调故障反馈；PWM 指令或缺失 RPM 不能证明电机损坏。",
                   pxEsc);
    }
    for (const QString& field : esc) {
        if (stopped()) {
            return {};
        }
        const bool counter = field.endsWith("esc_errorcount");
        const auto s = stats(log.fieldSamples[field], [](double v) { return v > 0; });
        if (!s.count) {
            continue;
        }
        QStringList decoded;
        if (!counter) {
            quint32 mask = 0;
            for (const QPointF& p : log.fieldSamples[field]) {
                if (std::isfinite(p.y()) && p.y() >= 0 && p.y() <= 65535) {
                    mask |= static_cast<quint32>(p.y());
                }
            }
            const QStringList meanings = {"过流",     "过压",     "电机过热",     "转速过高",     "控制指令不一致",
                                          "电机堵转", "通用故障", "电机温度预警", "电调温度预警", "电调过热"};
            for (int bit = 0; bit < meanings.size(); ++bit) {
                if (mask & (1u << bit)) {
                    decoded.append(meanings[bit]);
                }
            }
            if (mask & ~0x3ffu) {
                decoded.append("含未识别位，请核对该固件/厂家定义");
            }
        }
        report.append(row(
            "esc-" + field, "ESC / Motor（电调与电机）", (counter ? s.increases > 0 : s.max > 0) ? "suspect" : "info",
            rangeText(field, s) + (decoded.isEmpty() ? QString() : "；" + decoded.join("、")),
            QStringLiteral(
                "请查看电调故障反馈、RPM、电压/电流和输出指令。断电并拆桨后检查接线、焊点、桨毂、轴承和电调。"
                "不要仅因某一路输出高就断言电调或电机失效。"),
            {field}, pxEsc, s.firstMatch));
    }

    const auto power = matching(log,
                                "^(?:BAT(?:\\[\\d+\\])?\\.Volt|battery_status(?:\\[\\d+\\])?\\.(?:voltage_v|warning)|"
                                "POWR\\.Vcc|system_power\\.voltage5v_v)$");
    if (power.isEmpty()) {
        addMissing("power", "Power（供电）", "没有电池或板载供电记录。", pxAnalysis);
    }
    for (const QString& field : power) {
        const bool rail = field.endsWith("Vcc") || field.endsWith("voltage5v_v");
        const bool warning = field.endsWith("warning");
        const auto s = stats(log.fieldSamples[field],
                             [rail, warning](double v) { return warning ? v > 0 : rail && v > 0 && v < 4.7; });
        if (!s.count) {
            continue;
        }
        report.append(
            row("power-" + field, "Power（供电）", (warning ? s.max > 0 : rail && s.longest >= 1) ? "suspect" : "info",
                rangeText(field, s),
                QStringLiteral("请查看供电电压与错误事件的时间关系。零电压可能是无效记录。"
                               "5 V 供电低于 4.7 V 的持续段仅作参考；电池低压标准必须依据串数、化学体系和固件配置。"
                               "日志突然结束也可能是停止记录或 SD 卡故障，不能直接认定断电。"),
                {field}, diagnosis, s.firstMatch));
    }

    const auto motors = matching(log, "^actuator_motors(?:\\[\\d+\\])?\\.control\\[\\d+\\]$");
    for (const QString& field : motors) {
        if (stopped()) {
            return {};
        }
        const auto s = stats(log.fieldSamples[field], [](double v) { return v >= 0.95 && v <= 1.0; });
        if (!s.count || s.longest < 1) {
            continue;
        }
        report.append(
            row("motor-" + field, "Motor Output（电机指令接近上限）", "suspect",
                rangeText(field, s) + QStringLiteral("；0.95~1 最长连续 %1 s（参考筛查）").arg(s.longest, 0, 'f', 2),
                QStringLiteral("请查看目标/实际姿态及各电机输出，可能是推力余量不足或不平衡。"
                               "满油门操作也可能正常出现；此值是指令而非实测推力，不能直接认定电机/电调故障。"),
                motors, "https://docs.px4.io/main/en/log/flight_review", s.firstMatch));
    }

    const auto magX = matching(log, "^(?:MAG(?:\\[\\d+\\])?\\.MagX|sensor_mag(?:\\[\\d+\\])?\\.x)$");
    if (magX.isEmpty()) {
        addMissing("compass", "Compass（罗盘）", "没有三轴磁场记录，无法评估磁干扰。", pxAnalysis);
    }
    for (const auto& xName : magX) {
        const bool ap = xName.endsWith("MagX");
        const QString prefix = xName.left(xName.lastIndexOf('.') + 1);
        const QString yName = prefix + (ap ? "MagY" : "y"), zName = prefix + (ap ? "MagZ" : "z");
        if (!log.fieldSamples.contains(yName) || !log.fieldSamples.contains(zName)) {
            continue;
        }
        Samples norm;
        for (const auto& p : log.fieldSamples[xName]) {
            if (stopped()) {
                return {};
            }
            const double y = at(log.fieldSamples[yName], p.x()), z = at(log.fieldSamples[zName], p.x());
            const double strength = std::hypot(p.y(), y, z);
            if (std::isfinite(strength) && strength > 0) {
                norm.append({p.x(), strength});
            }
        }
        const auto s = stats(norm);
        if (!s.count) {
            continue;
        }
        const double variation = (s.max - s.min) / ((s.max + s.min) * 0.5);
        report.append(
            row("mag-" + xName, "Compass（磁场变化参考）", variation > 0.6 ? "suspect" : "info",
                QStringLiteral("三轴磁场模长 %1 ~ %2（日志原生单位）；相对范围变化 %3%。")
                    .arg(s.min, 0, 'g', 5)
                    .arg(s.max, 0, 'g', 5)
                    .arg(variation * 100, 0, 'f', 1),
                QStringLiteral("请查看 MagX/Y/Z 与油门、电流的同步变化。磁场模长随动力负载变化可能存在磁干扰；"
                               "校准问题、外部金属环境和单点异常也会造成变化，本项不能确认具体干扰源。"),
                {xName, yName, zName}, "https://docs.px4.io/main/en/log/flight_review"));
    }

    const Samples empty;
    const auto& subsystems = log.fieldSamples.value("ERR.Subsys", empty);
    const auto& codes = log.fieldSamples.value("ERR.ECode", empty);
    int shown = 0;
    for (const QPointF& p : codes) {
        if (stopped()) {
            return {};
        }
        const double subValue = at(subsystems, p.x(), 0.001);
        if (!std::isfinite(subValue) || !std::isfinite(p.y()) || subValue < 0 || subValue > 255 || p.y() < 0 ||
            p.y() > 255) {
            continue;
        }
        const int sub = static_cast<int>(subValue), code = static_cast<int>(p.y());
        const bool recovery = code == 0 && sub != 10 && sub != 24;
        if (shown++ >= 12) {
            continue;
        }
        report.append(row(
            QStringLiteral("err-%1").arg(shown), "ERR（机载错误与恢复）", recovery || sub == 24 ? "info" : "suspect",
            timeText(p.x(), log) + "\n" + LogFieldLabels::errorDescription(sub, code),
            QStringLiteral("对照该时刻的姿态、GPS、供电与输出；恢复事件不删除先前异常。旧版错误代码可能不同。"),
            {"ERR.Subsys", "ERR.ECode"},
            "https://github.com/ArduPilot/ardupilot/blob/master/libraries/AP_Logger/AP_Logger.h", p.x()));
    }
    if (shown > 12) {
        report.append(row("err-extra", "ERR（更多事件）", "info",
                          QStringLiteral("另有 %1 条 ERR，请打开 Messages（消息）查看。").arg(shown - 12), "",
                          {"ERR.Subsys", "ERR.ECode"}, apLogs));
    }

    // Attitude divergence is a lead, never a unique ESC/motor diagnosis.
    bool haveAttitude = false;
    for (const QString& axis : {QStringLiteral("Roll"), QStringLiteral("Pitch")}) {
        const QString desired = "ATT.Des" + axis, actual = "ATT." + axis;
        if (!log.fieldSamples.contains(desired) || !log.fieldSamples.contains(actual)) {
            continue;
        }
        haveAttitude = true;
        Samples errors;
        for (const QPointF& p : log.fieldSamples[actual]) {
            if (stopped()) {
                return {};
            }
            const double target = at(log.fieldSamples[desired], p.x());
            if (std::isfinite(target) && std::isfinite(p.y())) {
                errors.append({p.x(), std::abs(std::remainder(p.y() - target, 360.0))});
            }
        }
        const auto s = stats(errors, [](double v) { return v > 20; });
        if (!s.count) {
            continue;
        }
        auto evidenceFields = QStringList{desired, actual};
        evidenceFields.append(matching(log, "^RCOU\\.C\\d+$"));
        report.append(
            row("att-" + axis, "Attitude Divergence（姿态跟踪偏离）", s.longest >= 0.5 ? "suspect" : "info",
                QStringLiteral("%1 目标与实际差值最大 %2°，>20° 最长 %3 s（参考筛查）")
                    .arg(axis)
                    .arg(s.max, 0, 'f', 1)
                    .arg(s.longest, 0, 'f', 2),
                QStringLiteral("可能存在动力/执行器或控制异常，请查看目标与实际姿态和 RCOU 输出。"
                               "检查电调不同步、桨脱落/打滑、动力余量；也需排除撞击、解锁前姿态变化和状态估计异常。"),
                evidenceFields, diagnosis, s.firstMatch));
    }
    if (!haveAttitude) {
        addMissing("attitude", "Attitude Divergence（姿态跟踪偏离）",
                   "缺少 AP ATT.DesRoll/DesPitch 与实际姿态。PX4 四元数需另行分析，不直接套用角度规则。", pxAnalysis);
    }

    // Only rate tracking statistics are offered: these cannot identify safe numerical PID gains.
    bool havePid = false;
    const auto& armed = log.fieldSamples.value("ARM.ArmState", empty);
    const auto& landed = log.fieldSamples.value("vehicle_land_detected.landed", empty);
    for (int axis = 0; axis < 3; ++axis) {
        const QString letter = QStringList{"R", "P", "Y"}[axis];
        QString target = "RATE." + letter + "Des", actual = "RATE." + letter;
        const bool ap = log.fieldSamples.contains(target);
        if (!ap) {
            target = "vehicle_rates_setpoint." + QStringList{"roll", "pitch", "yaw"}[axis];
            actual = QStringLiteral("vehicle_angular_velocity.xyz[%1]").arg(axis);
        }
        if (!log.fieldSamples.contains(target) || !log.fieldSamples.contains(actual) ||
            (ap ? armed.isEmpty() : landed.isEmpty())) {
            continue;
        }
        double sumSquares = 0, sumTargets = 0;
        int count = 0;
        for (const QPointF& p : log.fieldSamples[actual]) {
            if (stopped()) {
                return {};
            }
            const double state = at(ap ? armed : landed, p.x(), 1.0);
            const double desired = at(log.fieldSamples[target], p.x(), 0.05);
            if (!std::isfinite(state) || !std::isfinite(desired) || !std::isfinite(p.y()) ||
                (ap ? state < 0.5 : state > 0.5)) {
                continue;
            }
            sumSquares += (p.y() - desired) * (p.y() - desired);
            sumTargets += desired * desired;
            ++count;
        }
        if (count < 100) {
            continue;
        }
        havePid = true;
        report.append(row("pid-" + letter, "PID Review（本地角速度跟踪参考）", "info",
                          QStringLiteral("%1 轴：%2 个同步有效样本；误差 RMS=%3 %4；目标 RMS=%5。")
                              .arg(letter)
                              .arg(count)
                              .arg(std::sqrt(sumSquares / count), 0, 'f', 3)
                              .arg(ap ? "deg/s" : "rad/s")
                              .arg(std::sqrt(sumTargets / count), 0, 'f', 3),
                          QStringLiteral("先确认无振动、削顶和输出饱和，再比较目标/实际是否迟滞、超调或持续振荡。"
                                         "本工具不计算可直接写入的 PID 数值；RMS 受操纵幅度和机型影响，无通用合格阈值。"
                                         "AP 按解锁状态筛选，可能包含地面段；PX4 按未着陆筛选，请人工确认有效飞行段。"),
                          {target, actual}, pxAnalysis));
    }
    if (!havePid) {
        addMissing("pid", "PID Review（本地调参参考）",
                   "缺少目标/实际角速度、解锁/着陆状态或至少 100 个时间对齐样本，不能可靠提供 PID 建议。", pxAnalysis);
    }
    return report;
}
