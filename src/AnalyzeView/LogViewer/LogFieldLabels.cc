#include "LogFieldLabels.h"

#include <QtCore/QHash>
#include <QtCore/QRegularExpression>

namespace {
const QHash<QString, QString> groups = {{"ACC", "加速度计"},
                                        {"ADSB", "ADS-B 航空器信息"},
                                        {"AHR2", "备用姿态航向估计"},
                                        {"ANG", "姿态控制"},
                                        {"ARM", "解锁状态"},
                                        {"ATT", "姿态"},
                                        {"AUXF", "辅助功能"},
                                        {"BARO", "气压计"},
                                        {"BAT", "电池"},
                                        {"BATT", "电池"},
                                        {"CAND", "CAN 驱动"},
                                        {"CANS", "CAN 接口统计"},
                                        {"CTUN", "高度控制调试"},
                                        {"CTRL", "控制器"},
                                        {"ERR", "子系统错误"},
                                        {"EV", "事件"},
                                        {"ESC", "电调遥测"},
                                        {"GPS", "卫星定位"},
                                        {"GPA", "GPS 精度"},
                                        {"GYR", "陀螺仪"},
                                        {"IMU", "惯性测量单元"},
                                        {"MAG", "磁力计"},
                                        {"MODE", "飞行模式"},
                                        {"MSG", "机载文本消息"},
                                        {"PARM", "参数"},
                                        {"POS", "位置"},
                                        {"RATE", "角速度控制"},
                                        {"RCIN", "遥控输入"},
                                        {"RCOU", "执行器输出"},
                                        {"RSSI", "接收信号强度"},
                                        {"VIBE", "振动与加速度计削顶"},
                                        {"PIDR", "横滚 PID"},
                                        {"PIDP", "俯仰 PID"},
                                        {"PIDY", "偏航 PID"},
                                        {"XKF1", "EKF3 状态估计"},
                                        {"XKF2", "EKF3 偏置估计"},
                                        {"XKF3", "EKF3 创新量"},
                                        {"XKF4", "EKF3 状态与检验"},
                                        {"NKF1", "EKF2 状态估计"},
                                        {"NKF3", "EKF2 创新量"},
                                        {"sensor_accel", "加速度计"},
                                        {"sensor_gyro", "陀螺仪"},
                                        {"sensor_mag", "磁力计"},
                                        {"sensor_gps", "卫星定位"},
                                        {"vehicle_gps_position", "卫星定位"},
                                        {"battery_status", "电池状态"},
                                        {"vehicle_attitude", "姿态四元数"},
                                        {"vehicle_attitude_setpoint", "目标姿态"},
                                        {"vehicle_angular_velocity", "机体角速度"},
                                        {"vehicle_rates_setpoint", "目标角速度"},
                                        {"vehicle_local_position", "局部位置"},
                                        {"vehicle_global_position", "全球位置"},
                                        {"vehicle_status", "飞行器状态"},
                                        {"vehicle_land_detected", "着陆检测"},
                                        {"vehicle_imu", "惯性测量"},
                                        {"vehicle_imu_status", "惯性传感器状态"},
                                        {"actuator_motors", "电机控制指令"},
                                        {"actuator_outputs", "执行器输出"},
                                        {"esc_report", "单个电调遥测"},
                                        {"esc_status", "电调状态"},
                                        {"estimator_status", "状态估计器检验"},
                                        {"estimator_status_flags", "状态估计器标志"},
                                        {"estimator_innovations", "状态估计器创新量"},
                                        {"input_rc", "遥控接收机输入"},
                                        {"manual_control_setpoint", "手动操纵目标"},
                                        {"telemetry_status", "遥测链路状态"}};
// Only unambiguous field names belong here. Short aliases such as I, R and P need their group.
const QHash<QString, QString> fields = {{"TimeUS", "启动后时间 / µs"},
                                        {"SampleUS", "采样时间 / µs"},
                                        {"timestamp", "启动后时间 / µs"},
                                        {"timestamp_sample", "采样时间 / µs"},
                                        {"Roll", "横滚角"},
                                        {"Pitch", "俯仰角"},
                                        {"Yaw", "偏航角"},
                                        {"DesRoll", "目标横滚角"},
                                        {"DesPitch", "目标俯仰角"},
                                        {"DesYaw", "目标偏航角"},
                                        {"Alt", "高度"},
                                        {"Lat", "纬度"},
                                        {"Lng", "经度"},
                                        {"lat", "纬度"},
                                        {"lon", "经度"},
                                        {"alt", "高度"},
                                        {"altitude_msl_m", "海拔高度 / m"},
                                        {"altitude_ellipsoid_m", "椭球高度 / m"},
                                        {"NSats", "参与定位卫星数"},
                                        {"HDop", "水平精度因子"},
                                        {"HDOP", "水平精度因子"},
                                        {"VDop", "垂直精度因子"},
                                        {"hdop", "水平精度因子"},
                                        {"vdop", "垂直精度因子"},
                                        {"satellites_used", "参与定位卫星数"},
                                        {"fix_type", "定位类型"},
                                        {"eph", "水平位置误差估计 / m"},
                                        {"epv", "垂直位置误差估计 / m"},
                                        {"AccX", "X 轴加速度"},
                                        {"AccY", "Y 轴加速度"},
                                        {"AccZ", "Z 轴加速度"},
                                        {"GyrX", "X 轴角速度"},
                                        {"GyrY", "Y 轴角速度"},
                                        {"GyrZ", "Z 轴角速度"},
                                        {"MagX", "X 轴磁场"},
                                        {"MagY", "Y 轴磁场"},
                                        {"MagZ", "Z 轴磁场"},
                                        {"VibeX", "X 轴振动 / m/s²"},
                                        {"VibeY", "Y 轴振动 / m/s²"},
                                        {"VibeZ", "Z 轴振动 / m/s²"},
                                        {"Clip0", "加速度计 0 削顶计数"},
                                        {"Clip1", "加速度计 1 削顶计数"},
                                        {"Clip2", "加速度计 2 削顶计数"},
                                        {"Volt", "电压"},
                                        {"Curr", "电流"},
                                        {"CurrTot", "累计耗电量"},
                                        {"Temp", "温度"},
                                        {"voltage_v", "电池电压 / V"},
                                        {"current_a", "电池电流 / A"},
                                        {"remaining", "剩余电量比例"},
                                        {"warning", "警告状态"},
                                        {"faults", "故障位掩码"},
                                        {"cell_count", "电池串数"},
                                        {"esc_rpm", "电机转速 / rpm"},
                                        {"RPM", "转速 / rpm"},
                                        {"esc_voltage", "电调电压 / V"},
                                        {"esc_current", "电调电流 / A"},
                                        {"esc_temperature", "电调温度 / °C"},
                                        {"esc_errorcount", "电调错误计数"},
                                        {"esc_failure_flags", "电调故障位掩码"},
                                        {"failures", "电调故障位掩码"},
                                        {"accel_vibration_metric", "加速度计振动指标"},
                                        {"gyro_vibration_metric", "陀螺仪振动指标"},
                                        {"accel_clipping", "加速度计削顶计数"},
                                        {"gyro_clipping", "陀螺仪削顶计数"},
                                        {"Subsys", "错误子系统编号"},
                                        {"ECode", "子系统错误代码"},
                                        {"ArmState", "解锁状态"},
                                        {"ArmChecks", "解锁检查位掩码"},
                                        {"Forced", "是否强制解锁"},
                                        {"nav_state", "导航模式"},
                                        {"arming_state", "解锁状态"},
                                        {"failsafe", "是否触发失控保护"},
                                        {"landed", "是否着陆"},
                                        {"roll", "横滚"},
                                        {"pitch", "俯仰"},
                                        {"yaw", "偏航"},
                                        {"Dt", "采样时间间隔"},
                                        {"VD", "向下速度"},
                                        {"VN", "北向速度"},
                                        {"VE", "东向速度"},
                                        {"Q1", "四元数分量 1"},
                                        {"Q2", "四元数分量 2"},
                                        {"Q3", "四元数分量 3"},
                                        {"Q4", "四元数分量 4"}};

QString baseGroup(QString group)
{
    group.remove(QRegularExpression(QStringLiteral("\\[\\d+\\]$")));
    return group;
}

QString bilingual(const QString& symbol, const QString& meaning)
{
    return meaning.isEmpty() ? symbol : symbol + QStringLiteral("（") + meaning + QStringLiteral("）");
}
}  // namespace

QString LogFieldLabels::groupLabel(const QString& group)
{
    return bilingual(group, groups.value(baseGroup(group)));
}

QString LogFieldLabels::fieldLabel(const QString& field, bool includeGroup)
{
    const QString group = baseGroup(field.section('.', 0, 0));
    const QString symbol = field.section('.', 1);
    QString key = symbol;
    key.remove(QRegularExpression(QStringLiteral("\\[\\d+\\]$")));
    QString meaning = fields.value(key);
    if (group == QStringLiteral("RATE")) {
        static const QHash<QString, QString> rate = {
            {"R", "实际横滚角速度"},    {"RDes", "目标横滚角速度"}, {"P", "实际俯仰角速度"},
            {"PDes", "目标俯仰角速度"}, {"Y", "实际偏航角速度"},    {"YDes", "目标偏航角速度"},
            {"ROut", "横滚控制输出"},   {"POut", "俯仰控制输出"},   {"YOut", "偏航控制输出"}};
        meaning = rate.value(key, meaning);
    } else if (group.startsWith(QStringLiteral("PID"))) {
        static const QHash<QString, QString> pid = {{"Tar", "目标值"}, {"Act", "实际值"},    {"Err", "控制误差"},
                                                    {"P", "比例项"},   {"I", "积分项"},      {"D", "微分项"},
                                                    {"FF", "前馈项"},  {"DFF", "微分前馈项"}};
        meaning = pid.value(key, meaning);
    } else if (key == QStringLiteral("I") && (group == "ACC" || group == "GYR" || group == "IMU" || group == "GPS" ||
                                              group == "MAG" || group == "BAT")) {
        meaning = QStringLiteral("传感器编号");
    } else if (key == QStringLiteral("Status") && group == QStringLiteral("GPS")) {
        meaning = QStringLiteral("定位类型");
    } else if (group == QStringLiteral("vehicle_angular_velocity") && key == QStringLiteral("xyz")) {
        meaning = QStringLiteral("机体轴角速度 / rad/s，索引 0/1/2 为 X/Y/Z");
    } else if (group == QStringLiteral("actuator_motors") && key == QStringLiteral("control")) {
        meaning = QStringLiteral("归一化电机指令；不是电机实测转速");
    } else if (group == QStringLiteral("RCOU") || group == QStringLiteral("RCIN")) {
        if (key.startsWith('C') && key.mid(1).toInt() > 0) {
            meaning =
                (group == "RCIN" ? QStringLiteral("遥控输入通道 ") : QStringLiteral("执行器输出通道 ")) + key.mid(1);
        }
    }
    return bilingual(includeGroup ? field : symbol, meaning);
}

QString LogFieldLabels::errorDescription(int subsystem, int code)
{
    static const QHash<int, QString> systems = {{1, "Main（主系统）"},
                                                {2, "Radio（遥控接收）"},
                                                {3, "Compass（罗盘）"},
                                                {4, "Optical Flow（光流）"},
                                                {5, "Radio Failsafe（遥控失控保护）"},
                                                {6, "Battery Failsafe（电池保护）"},
                                                {7, "GPS Failsafe（GPS 保护，旧版）"},
                                                {8, "GCS Failsafe（地面站通信保护）"},
                                                {9, "Fence（地理围栏）"},
                                                {10, "Flight Mode（模式切换）"},
                                                {11, "GPS（卫星定位）"},
                                                {12, "Crash Check（碰撞与失控检测）"},
                                                {13, "Flip（翻转）"},
                                                {14, "AutoTune（自动调参）"},
                                                {15, "Parachute（降落伞）"},
                                                {16, "EKF Check（状态估计检查）"},
                                                {17, "EKF Failsafe（状态估计保护）"},
                                                {18, "Barometer（气压计）"},
                                                {19, "CPU（处理器）"},
                                                {20, "ADS-B Failsafe（空中交通保护）"},
                                                {21, "Terrain（地形数据）"},
                                                {22, "Navigation（导航）"},
                                                {23, "Terrain Failsafe（地形保护）"},
                                                {24, "EKF Primary（主状态估计器切换）"},
                                                {25, "Thrust Loss（推力不足检测）"},
                                                {26, "Sensor Failsafe（传感器保护）"},
                                                {27, "Leak Failsafe（渗漏保护）"},
                                                {28, "Pilot Input（驾驶员输入）"},
                                                {29, "Vibration Failsafe（振动保护）"},
                                                {30, "Internal Error（内部错误）"},
                                                {31, "Dead Reckoning（航位推算保护）"}};
    QString meaning = QStringLiteral("含义依赖飞行器类型和固件版本，请核对该版本官方定义");
    // Mode-change codes are requested mode IDs, NOT ERROR_RESOLVED.
    if (subsystem == 10) {
        meaning = QStringLiteral("无法切换到请求模式，模式编号 %1").arg(code);
    } else if (subsystem == 24) {
        meaning = QStringLiteral("主 EKF 编号变更为 %1，不应直接视为硬件故障").arg(code);
    } else if (code == 0) {
        meaning = QStringLiteral("该项错误或保护状态已恢复；不代表全部故障已排除");
    } else if (subsystem == 11 && code == 2) {
        meaning = QStringLiteral("GPS 数据跳变（Glitch）；查看 HDop、NSats、Status 和位置曲线");
    } else if (subsystem == 16 && code == 2) {
        meaning = QStringLiteral("EKF 方差检查异常；查看定位、罗盘和惯性传感器数据");
    } else if (subsystem == 12 && code == 1) {
        meaning = QStringLiteral("飞控检测到碰撞条件；结合姿态、电机输出和落地时刻核实");
    } else if (subsystem == 12 && code == 2) {
        meaning = QStringLiteral("飞控检测到失控条件");
    } else if ((subsystem == 3 || subsystem == 4) && code == 1) {
        meaning = QStringLiteral("传感器初始化失败；先检查供电、接线与驱动配置");
    } else if (subsystem == 2 && code == 2) {
        meaning = QStringLiteral("遥控接收帧更新过迟（现代固件 RADIO_LATE_FRAME=2）");
    } else if (code == 1 && (subsystem == 5 || subsystem == 6 || subsystem == 7 || subsystem == 8 || subsystem == 17 ||
                             subsystem == 29)) {
        meaning = QStringLiteral("保护已触发；检查对应输入、通信或传感器数据，不要关闭安全检查来掩盖故障");
    }
    return QStringLiteral("ERR: Subsys=%1, ECode=%2 — %3\n%4")
        .arg(subsystem)
        .arg(code)
        .arg(systems.value(subsystem, QStringLiteral("Unknown（未知子系统）")), meaning);
}
