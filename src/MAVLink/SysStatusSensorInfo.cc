#include "SysStatusSensorInfo.h"
#include "QGCLoggingCategory.h"
#include "QGCMAVLink.h"

#include <QtCore/QHash>

QGC_LOGGING_CATEGORY(SysStatusSensorInfoLog, "MAVLink.SysStatusSensorInfo")

namespace {
QString bilingualSensorName(const QString &englishName)
{
    static const QHash<QString, QString> names = {
        {QStringLiteral("Gyro"), QStringLiteral("陀螺仪（Gyroscope）")},
        {QStringLiteral("Accelerometer"), QStringLiteral("加速度计（Accelerometer）")},
        {QStringLiteral("Magnetometer"), QStringLiteral("磁力计（Magnetometer）")},
        {QStringLiteral("Absolute pressure"), QStringLiteral("绝对气压计（Barometer）")},
        {QStringLiteral("Differential pressure"), QStringLiteral("差压传感器（Differential Pressure）")},
        {QStringLiteral("GPS"), QStringLiteral("全球定位系统（GPS）")},
        {QStringLiteral("Optical flow"), QStringLiteral("光流（Optical Flow）")},
        {QStringLiteral("Computer vision position"), QStringLiteral("视觉定位（Vision Position）")},
        {QStringLiteral("Laser based position"), QStringLiteral("激光定位（Laser Position）")},
        {QStringLiteral("External ground truth"), QStringLiteral("外部真值（External Ground Truth）")},
        {QStringLiteral("Angular rate control"), QStringLiteral("角速度控制（Angular Rate Control）")},
        {QStringLiteral("Attitude stabilization"), QStringLiteral("姿态稳定（Attitude Stabilization）")},
        {QStringLiteral("Yaw position"), QStringLiteral("航向控制（Yaw Control）")},
        {QStringLiteral("Z/altitude control"), QStringLiteral("高度控制（Z/Altitude Control）")},
        {QStringLiteral("X/Y position control"), QStringLiteral("水平位置控制（X/Y Position Control）")},
        {QStringLiteral("Motor outputs / control"), QStringLiteral("电机输出/控制（Motor Outputs/Control）")},
        {QStringLiteral("RC receiver"), QStringLiteral("遥控接收机（RC Receiver）")},
        {QStringLiteral("Gyro 2"), QStringLiteral("陀螺仪 2（Gyroscope 2）")},
        {QStringLiteral("Accelerometer 2"), QStringLiteral("加速度计 2（Accelerometer 2）")},
        {QStringLiteral("Magnetometer 2"), QStringLiteral("磁力计 2（Magnetometer 2）")},
        {QStringLiteral("GeoFence"), QStringLiteral("地理围栏（GeoFence）")},
        {QStringLiteral("AHRS"), QStringLiteral("姿态航向参考系统（AHRS）")},
        {QStringLiteral("Terrain"), QStringLiteral("地形数据（Terrain）")},
        {QStringLiteral("Motors reversed"), QStringLiteral("电机反转（Motors Reversed）")},
        {QStringLiteral("Logging"), QStringLiteral("日志记录（Logging）")},
        {QStringLiteral("Battery"), QStringLiteral("电池（Battery）")},
        {QStringLiteral("Proximity"), QStringLiteral("近距传感器（Proximity）")},
        {QStringLiteral("Satellite Communication"), QStringLiteral("卫星通信（Satellite Communication）")},
        {QStringLiteral("Pre-Arm Check"), QStringLiteral("解锁前检查（Pre-Arm Check）")},
        {QStringLiteral("Avoidance/collision prevention"), QStringLiteral("避障/防碰撞（Obstacle Avoidance）")},
        {QStringLiteral("Propulsion"), QStringLiteral("推进系统（Propulsion）")},
    };
    return names.value(englishName, englishName);
}
}

SysStatusSensorInfo::SysStatusSensorInfo(QObject *parent)
    : QObject(parent)
{
    // qCDebug(SysStatusSensorInfoLog) << Q_FUNC_INFO << this;
}

SysStatusSensorInfo::~SysStatusSensorInfo()
{
    // qCDebug(SysStatusSensorInfoLog) << Q_FUNC_INFO << this;
}

void SysStatusSensorInfo::update(const mavlink_sys_status_t &sysStatus)
{
    bool dirty = false;

    // Walk the bits
    for (int bitPosition = 0; bitPosition < 32; bitPosition++) {
        const MAV_SYS_STATUS_SENSOR sensorBitMask = static_cast<MAV_SYS_STATUS_SENSOR>(1 << bitPosition);
        if (sysStatus.onboard_control_sensors_present & sensorBitMask) {
            if (_sensorInfoMap.contains(sensorBitMask)) {
                SensorInfo &sensorInfo = _sensorInfoMap[sensorBitMask];

                const bool newEnabled = sysStatus.onboard_control_sensors_enabled & sensorBitMask;
                if (sensorInfo.enabled != newEnabled) {
                    dirty = true;
                    sensorInfo.enabled = newEnabled;
                }

                const bool newHealthy = sysStatus.onboard_control_sensors_health & sensorBitMask;
                if (sensorInfo.healthy != newHealthy) {
                    dirty = true;
                    sensorInfo.healthy = newHealthy;
                }
            } else {
                dirty = true;
                const SensorInfo sensorInfo = { !!(sysStatus.onboard_control_sensors_enabled & sensorBitMask), !!(sysStatus.onboard_control_sensors_health & sensorBitMask) };
                _sensorInfoMap[sensorBitMask] = sensorInfo;
            }
        } else if (_sensorInfoMap.contains(sensorBitMask)) {
            dirty = true;
            (void) _sensorInfoMap.remove(sensorBitMask);
        }
    }

    if (dirty) {
        emit sensorInfoChanged();
    }
}

QStringList SysStatusSensorInfo::sensorNames() const
{
    QStringList rgNames;

    // List ordering is unhealthy, healthy, disabled
    for (std::pair<MAV_SYS_STATUS_SENSOR, const SensorInfo&> sensorInfo : _sensorInfoMap.asKeyValueRange()) {
        if (sensorInfo.second.enabled && !sensorInfo.second.healthy) {
            rgNames.append(bilingualSensorName(QGCMAVLink::mavSysStatusSensorToString(sensorInfo.first)));
        }
    }

    for (std::pair<MAV_SYS_STATUS_SENSOR, const SensorInfo&> sensorInfo : _sensorInfoMap.asKeyValueRange()) {
        if (sensorInfo.second.enabled && sensorInfo.second.healthy) {
            rgNames.append(bilingualSensorName(QGCMAVLink::mavSysStatusSensorToString(sensorInfo.first)));
        }
    }

    for (std::pair<MAV_SYS_STATUS_SENSOR, const SensorInfo&> sensorInfo : _sensorInfoMap.asKeyValueRange()) {
        if (!sensorInfo.second.enabled) {
            rgNames.append(bilingualSensorName(QGCMAVLink::mavSysStatusSensorToString(sensorInfo.first)));
        }
    }

    return rgNames;
}

QStringList SysStatusSensorInfo::sensorStatus() const
{
    QStringList rgStatus;

    // List ordering is unhealthy, healthy, disabled
    for (const SensorInfo &sensorInfo : _sensorInfoMap.values()) {
        if (sensorInfo.enabled && !sensorInfo.healthy) {
            rgStatus.append(tr("Error"));
        }
    }

    for (const SensorInfo &sensorInfo : _sensorInfoMap.values()) {
        if (sensorInfo.enabled && sensorInfo.healthy) {
            rgStatus.append(tr("Normal"));
        }
    }

    for (const SensorInfo &sensorInfo : _sensorInfoMap.values()) {
        if (!sensorInfo.enabled) {
            rgStatus.append(tr("Disabled"));
        }
    }

    return rgStatus;
}
