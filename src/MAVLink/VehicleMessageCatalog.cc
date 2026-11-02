#include "VehicleMessageCatalog.h"

#include <QtCore/QRegularExpression>

#include <iterator>
#include <array>

namespace {
struct MessageEntry {
    const char *pattern;
    const char *translation;
    const char *solution;
};

static const MessageEntry reviewedEntries[] = {
#include "VehicleMessageCatalogManual.inc"
};

static const MessageEntry px4Entries[] = {
    {"Found 0 compass (required: 1)", "未检测到可用罗盘，但当前配置要求至少一个罗盘。", "检查罗盘供电与接线，在参数中启用正确的罗盘，然后重新校准。"},
    {"Waiting for compass (found {1}, required: {2})", "检测到的罗盘数量少于系统要求。", "检查罗盘接线和启用参数；不使用的罗盘请禁用，使用的罗盘请完成校准。"},
    {"Compass inconsistent", "多个罗盘的航向测量不一致。", "远离磁干扰并重新校准罗盘；若只使用一个罗盘，请禁用其余罗盘。"},
    {"Compass sensor {1} missing", "指定的罗盘传感器未检测到。", "检查罗盘供电、总线和参数配置，或禁用不存在的罗盘。"},
    {"No valid data from Compass {1}", "指定罗盘没有输出有效数据。", "检查罗盘连接和方向设置，重启飞控后重新校准。"},
    {"Compass {1} uncalibrated", "指定罗盘尚未校准。", "在传感器设置中完成罗盘校准后重新检查。"},
    {"Estimator fault due to Compass {1}", "估计器检测到罗盘故障。", "远离磁干扰，检查罗盘方向并重新校准；必要时禁用故障罗盘。"},
    {"Navigation error: No valid position estimate", "导航错误：没有有效的本地位置估计。", "等待 EKF 收敛；检查 IMU、气压计、光流或 GNSS 数据，并确认所选模式所需的位置源可用。"},
    {"Navigation error: No valid global position estimate", "导航错误：没有有效的全球位置估计。", "移至开阔区域等待 GNSS 定位，检查卫星数和定位精度，并等待 Home 点建立。"},
    {"Navigation error: No valid altitude estimate", "导航错误：没有有效的高度估计。", "检查气压计和测距仪数据，静置飞行器并等待 EKF 高度估计稳定。"},
    {"No manual control input", "未检测到手动控制输入。", "打开遥控器并确认接收机已连接；检查 RC 输入配置，或在无需遥控器时调整 COM_RC_IN_MODE。"},
    {"No valid attitude estimate", "没有有效的姿态估计。", "保持飞行器静止，检查并校准加速度计和陀螺仪，然后重启飞控。"},
    {"Heading estimate invalid", "航向估计无效。", "检查罗盘或 GNSS 航向源，远离磁干扰并等待估计器收敛。"},
    {"Horizontal position unstable", "水平位置估计不稳定。", "等待 GNSS/EKF 收敛，检查振动、卫星环境和位置传感器质量。"},
    {"Height estimate not stable", "高度估计不稳定。", "静置飞行器，避免气压计受风，检查气压计与测距仪数据。"},
    {"GPS fix too low", "GNSS 定位类型不足。", "移至开阔区域并等待更高质量定位，检查天线、供电和接线。"},
    {"Not enough GPS Satellites", "GNSS 可用卫星数量不足。", "移至开阔区域，检查天线朝向和遮挡，并等待搜星完成。"},
    {"GPS PDOP too high", "GNSS 卫星几何精度过差。", "等待更多卫星或移至遮挡更少的位置后再解锁。"},
    {"GPS Horizontal Position Error too high", "GNSS 水平位置误差过大。", "检查天线环境和干扰，等待定位精度改善。"},
    {"GPS Vertical Position Error too high", "GNSS 垂直位置误差过大。", "检查 GNSS 天线环境并等待定位精度改善。"},
    {"GPS signal spoofed", "GNSS 信号疑似被欺骗。", "立即停止解锁或飞行，远离干扰源并核对位置；检查 GNSS 安装与环境。"},
    {"GPS signal jammed", "GNSS 信号受到干扰。", "远离射频干扰源，检查天线布置和线缆屏蔽。"},
    {"GPS {1} offline", "指定 GNSS 接收机离线。", "检查该 GNSS 的供电、串口/CAN 接线和协议配置。"},
    {"GPS receivers disagree", "多个 GNSS 接收机报告的位置差异过大。", "检查各天线安装位置、定位质量和干扰，待位置一致后再解锁。"},
    {"Accelerometer sensor {1} missing", "指定加速度计未检测到。", "检查传感器硬件与总线连接，或修正启用配置。"},
    {"No valid data from Accelerometer {1}", "指定加速度计没有有效数据。", "重启飞控并检查传感器连接；若仍出现，请排查硬件。"},
    {"Accelerometer {1} uncalibrated", "指定加速度计尚未校准。", "保持机体稳定并完成加速度计六面校准。"},
    {"Accel {1} inconsistent", "多个加速度计测量不一致。", "检查振动和安装，重新校准加速度计；持续异常时检查硬件。"},
    {"High Accelerometer Bias", "加速度计零偏过大。", "静置并重新校准加速度计，检查温度变化、振动和安装应力。"},
    {"Gyro sensor {1} missing", "指定陀螺仪未检测到。", "检查传感器硬件和总线连接，或修正启用配置。"},
    {"No valid data from Gyro {1}", "指定陀螺仪没有有效数据。", "重启飞控并检查传感器连接；若仍出现，请排查硬件。"},
    {"Gyro {1} uncalibrated", "指定陀螺仪尚未校准。", "保持飞行器完全静止，重新启动或执行陀螺仪校准。"},
    {"Gyro {1} inconsistent", "多个陀螺仪测量不一致。", "静置飞行器并检查振动，重新校准；持续异常时检查硬件。"},
    {"High Gyro Bias", "陀螺仪零偏过大。", "保持飞行器静止并重启，检查振动和温度；必要时校准或更换传感器。"},
    {"No barometer enabled", "未启用气压计。", "检查气压计驱动和参数，至少启用一个可用气压计。"},
    {"No valid barometer data", "没有有效的气压计数据。", "检查气压计供电与总线，避免遮挡或强风直吹并重启飞控。"},
    {"Barometer {1} missing", "指定气压计未检测到。", "检查气压计连接和启用参数，或禁用不存在的气压计。"},
    {"Battery {1} missing", "指定电池监测器未检测到。", "检查电池连接、电源模块和电池监测参数。"},
    {"Battery {1} disconnected", "指定电池已断开。", "停止解锁并检查电池插头、电源模块和监测线。"},
    {"Battery unhealthy", "电池监测数据异常。", "检查电源模块接线、电压电流校准和电池状态。"},
    {"Low battery", "电池电量低。", "尽快降落或更换电池，并检查电池容量和低电量阈值。"},
    {"Critical battery", "电池电量严重不足。", "立即安全降落，检查电池和电源系统。"},
    {"Emergency battery level", "电池已到紧急电量。", "立即执行紧急降落并停止继续飞行。"},
    {"Airspeed invalid", "空速数据无效。", "检查空速计连接、管路和校准；无空速计配置时请正确禁用。"},
    {"Airspeed too high", "静止状态下空速读数过高。", "检查皮托管是否受风、堵塞或漏气，并重新校准空速计。"},
    {"No airspeed data", "没有空速数据。", "检查空速计供电、总线和管路，或核对是否应启用空速计。"},
    {"CPU load too high", "飞控 CPU 负载过高。", "关闭不必要功能或降低消息/日志频率，检查任务是否异常。"},
    {"RAM usage too high", "飞控内存占用过高。", "关闭不必要功能并重启飞控；检查固件和配置是否超出硬件能力。"},
    {"Missing FMU SD Card", "未检测到飞控 SD 卡。", "重新插入并检查 SD 卡，必要时备份后格式化或更换。"},
    {"Flying with USB is not safe", "仅通过 USB 供电飞行不安全。", "连接可靠的主电源后再解锁，USB 只用于调试和配置。"},
    {"Home position not set", "Home 点尚未建立。", "等待有效全球定位并确认 Home 点设置成功。"},
    {"No valid mission available", "没有可用的有效任务。", "重新上传并校验任务，修正无效航点或任务条件。"},
    {"No offboard signal", "未收到 Offboard 控制信号。", "启动外部控制程序并持续发送满足频率要求的设定值。"},
    {"Optical flow sensor missing", "未检测到光流传感器。", "检查光流传感器供电、总线和启用参数。"},
    {"No valid data from optical flow sensor", "光流传感器没有有效数据。", "检查镜头、照明、地面纹理、安装方向和数据连接。"},
    {"ESC telemetry missing", "缺少电调遥测。", "检查电调遥测线、协议和电调数量配置。"},
    {"Not all ESCs are armed", "并非所有电调均已就绪。", "立即停止解锁，检查电调供电、信号线和故障状态。"},
};

static const MessageEntry apmEntries[] = {
#include "VehicleMessageCatalogAPM.inc"
};

QString normalized(QString text)
{
    text.replace(QStringLiteral("&amp;"), QStringLiteral("&"));
    text.replace(QStringLiteral("&lt;"), QStringLiteral("<"));
    text.replace(QStringLiteral("&gt;"), QStringLiteral(">"));
    text = text.toLower().simplified();
    static const QRegularExpression prefix(
        QStringLiteral("^(?:prearm|preflight(?: fail)?|arm|critical|error|warning)\\s*:\\s*"),
        QRegularExpression::CaseInsensitiveOption);
    while (text.contains(prefix)) {
        text.remove(prefix);
    }
    static const QRegularExpression values(QStringLiteral("\\{[^}]+\\}|%[-+0-9.]*[a-z]|[-+]?\\d+(?:\\.\\d+)?"),
                                           QRegularExpression::CaseInsensitiveOption);
    text.replace(values, QStringLiteral("#"));
    return text.simplified();
}

struct PreparedEntry {
    QString pattern;
    VehicleMessageGuidance guidance;
};

template<size_t Count>
auto prepareEntries(const MessageEntry (&entries)[Count])
{
    std::array<PreparedEntry, Count> result;
    for (size_t i = 0; i < Count; ++i) {
        result[i] = {normalized(QString::fromUtf8(entries[i].pattern)),
                     {QString::fromUtf8(entries[i].translation), QString::fromUtf8(entries[i].solution), {}}};
    }
    return result;
}

template<size_t Count>
VehicleMessageGuidance findEntry(const QString &candidate, const std::array<PreparedEntry, Count> &entries)
{
    for (const auto &entry : entries) {
        if (candidate == entry.pattern || (entry.pattern.size() >= 8 && candidate.contains(entry.pattern))) {
            return entry.guidance;
        }
    }
    return {};
}

VehicleMessageGuidance withExplanation(VehicleMessageGuidance guidance, const QString &candidate)
{
    if (guidance.isEmpty()) {
        return guidance;
    }
    struct ExplanationEntry { const char *pattern; const char *explanation; };
    static const ExplanationEntry entries[] = {
#include "VehicleMessageExplanations.inc"
    };
    static const auto prepared = [] {
        std::array<std::pair<QString, QString>, std::size(entries)> result;
        for (size_t i = 0; i < std::size(entries); ++i) {
            result[i] = {normalized(QString::fromUtf8(entries[i].pattern)), QString::fromUtf8(entries[i].explanation)};
        }
        return result;
    }();
    for (const auto &entry : prepared) {
        if (candidate.contains(entry.first)) {
            guidance.explanation = entry.second;
            break;
        }
    }
    if (guidance.explanation.isEmpty()) {
        guidance.explanation = QStringLiteral("这是飞控上报的检查结果。结合原始报错、发生时间及同一时段的其他告警核对触发条件，按下面步骤逐项检查。");
    }
    return guidance;
}
}

VehicleMessageGuidance VehicleMessageCatalog::lookup(const QString &message, VehicleMessageStack stack)
{
    // QML may read the whole warning list repeatedly in a single telemetry burst.
    // Normalize the immutable catalog once, not once per entry per property read.
    static const auto reviewedCatalog = prepareEntries(reviewedEntries);
    static const auto px4Catalog = prepareEntries(px4Entries);
    static const auto apmCatalog = prepareEntries(apmEntries);
    const QString candidate = normalized(message);
    const auto reviewed = findEntry(candidate, reviewedCatalog);
    if (!reviewed.isEmpty()) return withExplanation(reviewed, candidate);
    if (stack == VehicleMessageStack::PX4 || stack == VehicleMessageStack::Any) {
        VehicleMessageGuidance result = findEntry(candidate, px4Catalog);
        if (!result.isEmpty()) {
            return withExplanation(result, candidate);
        }
    }
    if (stack == VehicleMessageStack::ArduPilot || stack == VehicleMessageStack::Any) {
        return withExplanation(findEntry(candidate, apmCatalog), candidate);
    }
    return {};
}
