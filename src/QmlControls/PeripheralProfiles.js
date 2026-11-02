.pragma library

// Parameter recipes are previews only. All reads/writes remain in the dialog's Fact controller.
var gpsSource = "https://ardupilot.org/copter/docs/common-gps.html"
var mosaicSource = "https://docs.holybro.com/gps-and-rtk-system/h-rtk-mosaic-h/setup-and-getting-started-ardupilot"
var unicoreSource = "https://docs.holybro.com/gps-and-rtk-system/h-rtk-unicore-um982/setup-and-getting-started-ardupilot"
var micoSource = "https://micoair.cn/zh/docs/sensors/sensors/"
var elrsSource = "https://www.expresslrs.org/quick-start/ardupilot-setup/"
var elrsMavlinkSource = "https://www.expresslrs.org/software/mavlink/"
var lightwareSource = "https://ardupilot.org/copter/docs/common-lightware-sf10-lidar.html"
var categories = [
    {key: "gps", name: "GNSS 定位"}, {key: "flow", name: "光流 / 视觉"},
    {key: "range", name: "激光雷达"}, {key: "rc", name: "ELRS 遥控"},
    {key: "telemetry", name: "数传"}, {key: "power", name: "电源模块"}
]
function category(profile) {
    if (profile.kind.indexOf("power-") === 0) return "power"
    if (profile.kind.indexOf("range") === 0) return "range"
    if (profile.kind.indexOf("flow") === 0 || profile.kind === "vio") return "flow"
    if (profile.kind === "elrs-crsf") return "rc"
    if (profile.kind === "telemetry" || profile.kind === "elrs-mavlink") return "telemetry"
    return "gps"
}
function isElrs(profile) { return profile.kind === "elrs-crsf" || profile.kind === "elrs-mavlink" }
function isRange(profile) { return profile.kind.indexOf("range") === 0 }
function sourceFor(profile, firmware) {
    if (firmware !== "px4") return profile.source
    if (profile.kind === "elrs-crsf") return "https://docs.px4.io/main/en/telemetry/crsf_telemetry"
    if (profile.px4Config === "SENS_SF0X_CFG") return "https://docs.px4.io/main/en/sensor/sfxx_lidar"
    if (profile.kind === "range" && profile.px4) return "https://docs.px4.io/main/en/sensor/tfmini"
    return profile.source
}
var profiles = [
    { name: "CUAV NEO 4SE（DroneCAN）", kind: "can", led: true, mag: true, source: gpsSource },
    { name: "CUAV NEO 3 Pro（DroneCAN）", kind: "can", led: true, mag: true, source: gpsSource },
    { name: "CUAV C-RTK（DroneCAN RTK）", kind: "can", mag: true, rtcm: true, source: gpsSource },
    { name: "Holybro H-RTK F9P（DroneCAN）", kind: "can", mag: true, rtcm: true, source: gpsSource },
    { name: "CubePilot Here3 / Here3+（DroneCAN）", kind: "can", mag: true, rtcm: true, source: gpsSource },
    { name: "Holybro H-RTK F9P（UART / UBX）", kind: "ubx", rtcm: true, baud: 115200, source: gpsSource },
    { name: "u-blox M8 / M9 / M10（UART / UBX）", kind: "ubx", baud: 115200, source: gpsSource },
    { name: "Holybro mosaic-H（UART / SBF 定位）", kind: "sbf", rtcm: true, baud: 230400, source: mosaicSource },
    { name: "Septentrio（UART / SBF）", kind: "sbf", rtcm: true, baud: 115200, source: mosaicSource },
    { name: "Holybro Unicore UM982（UART 定位）", kind: "unicore", rtcm: true, baud: 230400, source: unicoreSource },
    { name: "通用 NMEA GPS（UART）", kind: "nmea", baud: 115200, source: gpsSource },
    { name: "Benewake TFmini / TFmini Plus（UART）", kind: "range", apType: 20, px4: true, baud: 115200, source: "https://ardupilot.org/copter/docs/common-benewake-tfmini-lidar.html" },
    { name: "Benewake TF02（原版 UART）", kind: "range", apType: 19, baud: 115200, source: "https://ardupilot.org/copter/docs/common-benewake-tf02-lidar.html" },
    { name: "Benewake TF02-Pro / TF03 / TF-Luna（UART）", kind: "range", apType: 27, baud: 115200, source: "https://ardupilot.org/copter/docs/common-benewake-tf02-lidar.html" },
    { name: "Benewake TFmini Plus（I²C，0x10）", kind: "range-i2c", apType: 25, address: 16, source: "https://ardupilot.org/copter/docs/common-benewake-tfmini-lidar.html" },
    { name: "LightWare SF10/A（UART）", kind: "range", apType: 8, px4Config: "SENS_SF0X_CFG", px4Model: 2, baud: 115200, source: lightwareSource },
    { name: "LightWare SF10/B（UART）", kind: "range", apType: 8, px4Config: "SENS_SF0X_CFG", px4Model: 3, baud: 115200, source: lightwareSource },
    { name: "LightWare SF10/C（UART）", kind: "range", apType: 8, px4Config: "SENS_SF0X_CFG", px4Model: 4, baud: 115200, source: lightwareSource },
    { name: "LightWare SF11/C（UART）", kind: "range", apType: 8, px4Config: "SENS_SF0X_CFG", px4Model: 5, baud: 115200, source: lightwareSource },
    { name: "Lanbao PSK-CM8JL65-CC5（UART）", kind: "range", apType: 26, px4Config: "SENS_CM8JL65_CFG", baud: 115200, source: "https://ardupilot.org/copter/docs/common-lanbao-cm8jl65-lidar.html" },
    { name: "Garmin LIDAR-Lite v3（I²C）", kind: "range-i2c", apType: 15, px4Enable: "SENS_EN_LL40LS", px4Value: 2, source: "https://docs.px4.io/main/en/sensor/lidar_lite" },
    { name: "ExpressLRS / ELRS（CRSF 遥控）", kind: "elrs-crsf", baud: 420000, source: elrsSource },
    { name: "ExpressLRS / ELRS（MAVLink 遥控 + 数传）", kind: "elrs-mavlink", baud: 460800, source: elrsMavlinkSource },
    { name: "SiK / RFD / 通用 MAVLink2 数传（UART）", kind: "telemetry", baud: 57600, source: "https://ardupilot.org/copter/docs/common-telemetry-port-setup.html" },
    { name: "微空 MTF-01（UART 光流 / 测距）", kind: "flow", baud: 115200, maxRange: 5, source: micoSource + "mtf-01-sensors" },
    { name: "微空 MTF-01P（UART 光流 / 测距）", kind: "flow", baud: 115200, maxRange: 8, source: micoSource + "mtf-01p-sensors" },
    { name: "微空 MTF-02（UART 光流 / 测距；室内）", kind: "flow", baud: 115200, maxRange: 2.5, source: micoSource + "mtf-02-02p-sensors" },
    { name: "微空 MTF-02P（UART 光流 / 测距）", kind: "flow", baud: 115200, maxRange: 6, source: micoSource + "mtf-02-02p-sensors" },
    { name: "CUAV CAN PMU / CAN PMU Lite / CAN PDB", kind: "power-can", source: "https://doc.cuav.net/can-pdb/users-manual-for-apm.html" },
    { name: "Holybro DroneCAN 电源模块", kind: "power-can", ignoreSoc: true, source: "https://docs.holybro.com/power-module-and-pdb/power-module/dronecan-power-module-setup" },
    { name: "CUAV HV_PM（模拟）", kind: "power-analog", divider: 18, amps: 24, source: "https://doc.cuav.net/tutorial/copter/optional-hardware/power-modules/hv-pm.html" },
    { name: "Holybro PM02 / PM02 V3 / PM06 / PM07（模拟）", kind: "power-analog", divider: 18.182, amps: 36.364, source: "https://docs.holybro.com/power-module-and-pdb/power-module/analog-power-module-setup" },
    { name: "Holybro PM08（模拟，72 A/V）", kind: "power-analog", divider: 18.182, amps: 72, source: "https://docs.holybro.com/power-module-and-pdb/power-module/analog-power-module-setup" },
    { name: "Holybro PM02D / PM03D / PM06D（I²C，自动寻址）", kind: "power-i2c", source: "https://docs.holybro.com/power-module-and-pdb/power-module/digital-power-module-pm-setup" },
    { name: "微空 MicoVIO（视觉惯性 / MAVLink2）", kind: "vio", requiresVerification: true, variant: "micovio", baud: 921600, source: "https://micoair.cn/zh/docs/sensors/visual-inertial-odometry-sensor/micovio" },
    { name: "微空 MVD35 / OpenVINS（双目视觉 / 伴随计算机）", kind: "vio", requiresVerification: true, variant: "openvins", source: "https://micoair.cn/zh/docs/ai-tutorial/ai-tutorial-4-vio" },
    { name: "ModalAI VOXL 2 / VOXL 2 Mini（VIO）", kind: "vio", requiresVerification: true, variant: "voxl", baud: 921600, source: "https://docs.modalai.com/flying-with-vio/" },
    { name: "Holybro H-Flow（DroneCAN 光流）", kind: "flow-can", variant: "hflow", maxRange: 30, requiresVerification: true, source: "https://docs.holybro.com/peripherals/h-flow-dronecan/setup-guide" },
    { name: "ARK Flow（DroneCAN 光流）", kind: "flow-can", variant: "ark", maxRange: 30, requiresVerification: true, source: "https://docs.px4.io/main/en/dronecan/ark_flow" },
    { name: "ARK Flow MR（DroneCAN 光流）", kind: "flow-can", variant: "ark-mr", maxRange: 50, requiresVerification: true, source: "https://docs.px4.io/main/en/dronecan/ark_flow_mr" },
    { name: "CubePilot HereFlow（DroneCAN 光流）", kind: "flow-can", variant: "hereflow", maxRange: 4, requiresVerification: true, source: "https://docs.px4.io/main/en/sensor/pmw3901" },
    { name: "Holybro PMW3901（UART 光流，需独立测距）", kind: "flow-uart", requiresVerification: true, source: "https://docs.holybro.com/pmw3901-optical-flow-sensor" }
]

function guidance(profile, firmware) {
    if (isElrs(profile)) {
        var mavlink = profile.kind === "elrs-mavlink"
        return {parameters: [], preparation: [
            "接收机 TX 接飞控 RX、RX 接 TX 并共地，使用完整、非反相的 UART；供电按接收机型号核对。",
            mavlink ? "ELRS 发射模块须切换 MAVLink Link Mode；ELRS 3.x 还需在接收机 Other Devices 中设置 MAVLink，4.x 可随发射端自动设置。地面站只写飞控参数，不代替接收机对频或刷固件。" : "先完成 ELRS 对频，接收机输出选择 CRSF。此模式的遥测是给遥控器使用，不能当作完整 MAVLink 地面站数传。"
        ], verification: [mavlink ? "重启并确认遥控通道和双向 MAVLink 数据均正常；USB 外置模块走串口，TX Backpack 数传转发走 UDP 14550。AP 的 SRx/MAVx 速率须按实际 MAVLink 通道另行核对，串口号不等于通道号。" : "重启飞控与接收机后检查遥控通道、RSSI / LQ、失联状态和遥控接管。保持原有飞行模式映射及失控保护。",
            firmware === "px4" && !mavlink ? "PX4 需要固件含 CRSF 驱动；缺少 RC_CRSF_PRT_CFG 时必须先安装含该驱动的固件。" : "选择空闲接口，避免覆盖现有 GPS、遥控或当前数传。"]}
    }
    if (isRange(profile)) return {parameters: [], preparation: [
        profile.kind === "range-i2c" ? "确认模块当前为 I²C 输出并接入正确 I²C 总线，核对供电与地址；不能把 UART 型号直接按 I²C 配置。" : "确认模块当前为 UART 输出，交叉连接 TX/RX 并共地；核对型号、接口电平和串口。",
        "选择未占用的测距实例。最小/最大有效距离、朝向和离地高度须按实际型号及安装填写，本方案只启用接收驱动。",
        "AP 多串口测距按实例与串口顺序配对；顺序不匹配或混用本方案未识别的测距驱动时会阻止应用，请先核对现有接线。"
    ], verification: ["重启后查看 DISTANCE_SENSOR，改变真实距离核对读数、方向及超量程状态；不会自动替换 EKF 高度源或启用避障。",
        profile.apType === 26 ? "Lanbao 此型号的驱动有效范围上限为 6 m，最大距离不能设得更大。" : "强光、深色或透明物体会影响可用量程，请用实际环境验证。"]}
    if (profile.kind === "flow" && firmware === "ap") return {preparation: [
        "ArduPilot 4.5+ 按厂商要求把模块 mav_id 设为 200（不能为 1），并禁止所接串口转发；模块自身设置需使用厂商工具。",
        "4.5 之前不强加新版的禁止转发选项；按实际固件参数与型号教程配置。这里默认只启用接收驱动，不替换 EKF 高度源。"
    ], verification: ["重启后核对 OPTICAL_FLOW_RAD 与 DISTANCE_SENSOR；导航融合须另行审核。"], parameters: []}
    if (profile.kind === "flow" && firmware === "px4") return {preparation: [
        "先按实际接口配置接收；需要光流定位时，可另行勾选下方导航融合配置。会更改高度参考，须确认安装、量程和室内外使用条件。",
        "PX4 1.12–1.13：EKF2_AID_MASK 光流位、EKF2_RNG_AID、EKF2_HGT_MODE；1.14 起改为 EKF2_OF_CTRL、EKF2_RNG_CTRL、EKF2_HGT_REF。以飞控真实参数为准。",
        "PX4 1.17 起厂商要求额外核对 MAV_PROTO_VER=1；这是协议兼容设置，可能影响其他 MAVLink 链路，需单独勾选。旧固件不套用新版参数。"
    ], verification: ["重启后核对 OPTICAL_FLOW_RAD、DISTANCE_SENSOR 与估计器融合状态；仅收到传感器消息不等于已具备光流定位。"], parameters: []}
    if (!profile.requiresVerification) return {preparation: [], verification: [], parameters: []}
    var prep = ["核对当前飞控固件包含该型号驱动，并确认下表参数及枚举与厂商方案一致；勾选核对后可应用数字参数。",
        "该方案只写飞控参数，不代替模块固件、伴随计算机服务和相机/IMU 标定。红色安装偏移及延迟项不自动填写。"]
    if (profile.kind === "vio") {
        prep.push("先完成相机内参、相机/IMU 外参、时钟同步和 NED/FRD 坐标检查，再核对模组或伴随计算机输出。")
        if (profile.variant === "micovio") prep.push("MicoVIO：AP 厂商要求 4.5.2+；921600 8N1。AP 4.7+ 用实际 MAVLink 通道 OPTIONS，不能把通道号当串口号。")
        else if (profile.variant === "openvins") prep.push("MVD35 / OpenVINS：AP 表按厂商 VISION_POSITION_ESTIMATE 教程；PX4 表仅配置接收端口，融合配置需采用配套固件方案。伴随计算机仍需运行相机、MAVROS 和 OpenVINS。")
        else prep.push("VOXL：飞控表配置接收链路与对应驱动；完整 EKF 融合须与 VOXL SDK 1.6/1.8 对应配置包一致。本页不猜测整机配置，也不修改伴随计算机服务。")
    } else {
        prep.push(profile.kind === "flow-can" ? "核对 CAN_H/CAN_L、供电、共地、节点 ID 与两端终端电阻，按所选 CAN 口保留逻辑驱动绑定。" : "PMW3901 使用 UART 光流协议，不是 MAVLink 光流；须另外接入下视测距仪。")
        prep.push("按厂商方向向下安装，并准备有纹理、非反光地面；应用表中的 EKF 项可能改变定位或高度参考。")
        if (profile.variant === "hereflow") prep.push("HereFlow 内置测距的户外有效距离很短，4 m 仅为文档标称上限，厂商建议另外使用更长量程测距仪。")
    }
    return {preparation: prep, verification: ["应用后自行重启飞控并重新读取参数；新启用驱动的安装偏移项可能在重启后才出现。",
        "检查 OPTICAL_FLOW_RAD / DISTANCE_SENSOR 或 ODOMETRY 数据的质量、方向、量程与时序，手持移动核对估计器融合和失效退出。"], parameters: []}
}

var px4Ports = { GPS1: 201, GPS2: 202, TELEM1: 101, TELEM2: 102, TELEM3: 103, "TELEM/SERIAL4": 104, UART6: 6 }
var px4BaudNames = { GPS1: "SER_GPS1_BAUD", GPS2: "SER_GPS2_BAUD", TELEM1: "SER_TEL1_BAUD", TELEM2: "SER_TEL2_BAUD", TELEM3: "SER_TEL3_BAUD", "TELEM/SERIAL4": "SER_TEL4_BAUD", UART6: "SER_UART6_BAUD" }

function gpsNames(instance, suffix) {
    return instance === 1 ? ["GPS1_" + suffix, "GPS_" + suffix] : ["GPS2_" + suffix, "GPS_" + suffix + "2"]
}

function isPower(profile) { return profile.kind.indexOf("power-") === 0 }

// Analog ADC pins belong to the flight controller, not to the module brand.
var powerBoards = ["请选择实际飞控型号", "Pixhawk 6C / 6C Mini / Pix32 v6", "Pixhawk 4 / 4 Mini / Pix32v5 / CUAV V5", "Durandal", "CUAV V6X（外部 ADC，HV_PM）"]
var analogPins = { 1: [[8, 4], [5, 14]], 2: [[0, 1], [2, 3]], 3: [[16, 17], [14, 15]], 4: [[12, 13]] }
function batteryNames(instance, suffix) {
    return instance === 1 ? ["BATT1_" + suffix, "BATT_" + suffix] : ["BATT2_" + suffix]
}

// Factory recipes keep measured installation values out of automatic writes.
function installationRecipe(profile, firmware, port, instance, baud, options) {
    var rows = []
    if (firmware !== "ap" && firmware !== "px4") return rows
    if (!Number.isInteger(instance) || instance < 1 || instance > 4) return rows
    if (profile.kind === "flow-can" ? !["CAN1", "CAN2"].includes(port)
        : firmware === "ap" ? !/^SERIAL[1-8]$/.test(port) : !(port in px4Ports)) return rows
    function add(name, value, note, optional) { rows.push({names: Array.isArray(name) ? name : [name], value: value, note: note, optional: !!optional}) }
    function measured(name, note) { rows.push({names: Array.isArray(name) ? name : [name], manual: true, optional: true, note: note || "该参数需自行测量后写入；本页不自动修改。"}) }
    function offsets(prefix) { for (var axis of ["X", "Y", "Z"]) measured(prefix + axis) }
    function range(name, value, note) {
        add(["RNGFND" + instance + "_" + name, "RNGFND" + instance + "_" + name + "_CM"], value, note)
        rows[rows.length - 1].centimeterAlias = true
    }
    function apSources(position, velocity, height, vertical, yaw) {
        for (var pair of [["POSXY", position], ["VELXY", velocity], ["POSZ", height], ["VELZ", vertical], ["YAW", yaw]])
            add("EK3_SRC1_" + pair[0], pair[1], "厂商方案的 EKF3 来源；应用后须重启并检查融合")
    }
    if (profile.kind === "flow-can") {
        if (firmware === "ap") {
            var physical = port === "CAN2" ? 2 : 1
            var driver = options.canDriver > 0 ? options.canDriver : physical
            add("CAN_P" + physical + "_DRIVER", driver, "所选 CAN 物理接口绑定逻辑驱动，保留已有绑定")
            add("CAN_D" + driver + "_PROTOCOL", 1, "逻辑 CAN 驱动使用 DroneCAN")
            add("FLOW_TYPE", 6, "DroneCAN 光流驱动")
            add("RNGFND" + instance + "_TYPE", 24, "所选测距实例接收 DroneCAN 测距")
            range("MAX", profile.maxRange, "型号的标称上限（米），实际环境可用距离可能更短")
            if (profile.variant === "hflow") {
                add("EK3_SRC_OPTIONS", 0, "按 H-Flow 厂商方案禁用 FuseAllVelocities")
                apSources(0, 5, 2, 0, 1)
                rows.push({names: ["EK3_FLOW_DELAY"], keepCurrent: true, optional: true, note: "厂商要求保持默认；此项只显示当前值，不自动修改"})
            } else {
                add("EK3_SRC1_POSXY", 0, "光流无绝对水平位置来源")
                add("EK3_SRC1_VELXY", 5, "水平速度源使用 OpticalFlow；保留其他来源设置")
            }
            offsets("FLOW_POS_")
            offsets("RNGFND" + instance + "_POS_")
            measured("FLOW_ORIENT", "请按模块安装方向核对旋转角；本页不猜测安装方向。")
        } else {
            add("UAVCAN_ENABLE", 2, "启用 DroneCAN 传感器与动态节点分配")
            rows[rows.length - 1].minimumValue = true
            add("UAVCAN_SUB_FLOW", 1, "订阅光流")
            add("UAVCAN_SUB_RNG", 1, "订阅测距")
            if (options.modernFlow) add("EKF2_OF_CTRL", 1, "启用光流融合")
            else { add("EKF2_AID_MASK", 2, "旧固件追加光流融合位，保留已有位"); rows[rows.length-1].orMask = 2 }
            if (profile.variant !== "hereflow") {
                add(options.modernFlow ? "EKF2_RNG_CTRL" : "EKF2_RNG_AID", 1, "启用条件式测距辅助")
                add("EKF2_RNG_QLTY_T", 0.2, "厂商建议的测距质量时间", true)
                add("UAVCAN_RNG_MIN", 0.08, "型号最小测距（米）", true)
                add("UAVCAN_RNG_MAX", profile.maxRange, "型号标称测距上限（米）", true)
                add("SENS_FLOW_MINHGT", 0.08, "光流最小高度（米）", true)
                add("SENS_FLOW_MAXHGT", profile.variant === "hflow" ? 30 : 25, "型号的光流最大高度（米）", true)
                add("SENS_FLOW_MAXR", 7.4, "PAW3902 最大角流速", true)
                if (profile.variant === "hflow") add("EKF2_RNG_A_HMAX", 10, "H-Flow 厂商建议的测距辅助高度上限", true)
            }
            offsets("EKF2_OF_POS_")
            measured("SENS_FLOW_ROT", "需按实际安装方向确认，不自动代填。")
        }
    } else if (profile.kind === "flow-uart") {
        if (firmware === "ap") {
            add(port + "_PROTOCOL", 18, "Holybro PMW3901 的串口光流协议，不是 MAVLink 光流")
            add("FLOW_TYPE", 4, "CXOF / UART 驱动（厂商指定值）")
            offsets("FLOW_POS_")
            measured("FLOW_ORIENT", "需按实际安装方向确认，不自动代填。")
        } else {
            add("SENS_EN_PMW3901", 1, "按 Holybro 型号指南启用驱动")
            add("SENS_TFLOW_CFG", px4Ports[port], "实际连接 UART；不能覆盖其他串口设备")
            offsets("EKF2_OF_POS_")
            measured("SENS_FLOW_ROT", "需按实际安装方向确认，不自动代填。")
        }
        if (firmware === "ap") measured("RNGFND" + instance + "_TYPE", "PMW3901 不含对地测距；请另配下视测距仪并按实际型号配置。")
        else offsets("EKF2_RNG_POS_")
    } else if (profile.kind === "vio") {
        if (firmware === "ap") {
            add(port + "_PROTOCOL", 2, "视觉数据使用 MAVLink2")
            add(port + "_BAUD", baud === 921600 ? 921 : baud === 115200 ? 115 : baud / 1000, "与模组或伴随计算机配置一致")
            if (profile.variant === "micovio") {
                if (options.modernMavOptions) {
                    add(["MAV" + options.mavInstance + "_OPTIONS", "MAV_" + options.mavInstance + "_OPTIONS"], 2, "AP 4.7+：所选实际 MAVLink 通道禁转发；通道号不等于 SERIAL 号")
                    rows[rows.length - 1].orMask = 2
                } else {
                    add(port + "_OPTIONS", 1024, "旧固件串口禁止转发，保留其余位")
                    rows[rows.length - 1].orMask = 1024
                }
                add("VISO_TYPE", 3, "MicoVIO 的 ODOMETRY 接收驱动")
                add("VISO_YAW_M_NSE", 0.1, "厂商建议的视觉航向噪声")
                add("RNGFND" + instance + "_TYPE", 10, "接收 MicoVIO MAVLink 测距")
                range("MIN", 0.01, "厂商测距下限（米）")
                range("MAX", 12, "厂商测距上限（米）")
                add("RNGFND" + instance + "_ORIENT", 25, "仅适用于按厂商要求向下安装")
                apSources(6, 6, 2, 6, 6)
            } else if (profile.variant === "openvins") {
                add("VISO_TYPE", 1, "MVD35 / OpenVINS 的 VISION_POSITION_ESTIMATE 路线，不使用 MicoVIO 类型 3")
                add("BRD_RTC_TYPES", 2, "厂商教程使用 MAVLink 同步时间")
                apSources(6, 0, 2, 0, 6)
                // The GCS system ID belongs to the current installation, never copy the example's ID 1.
                measured("SYSID_MYGCS", "按当前地面站实际系统 ID 核对，不能照抄教程示例 ID。")
            } else {
                add("VISO_TYPE", 3, "VOXL / ODOMETRY 接收；融合来源按实际输出另行核对")
            }
            offsets("VISO_POS_")
            measured("VISO_DELAY_MS", "该参数需按日志测量延迟后写入；本页不猜测延迟。")
        } else {
            add("MAV_1_CONFIG", px4Ports[port], "视觉接收使用空闲 MAVLink 实例 1")
            add("MAV_1_MODE", 2, "Onboard 模式")
            add("MAV_1_FORWARD", 0, "禁止转发模块数据")
            add(px4BaudNames[port], baud, "与视觉模组或伴随计算机一致")
            if (profile.variant === "micovio") {
                add("EKF2_EV_CTRL", 9, "厂商配置：水平位置与视觉航向")
                add("EKF2_HGT_REF", 2, "厂商配置：测距高度参考")
            }
            offsets("EKF2_EV_POS_")
            measured("EKF2_EV_DELAY", "该参数需按日志测量延迟后写入；本页不猜测延迟。")
        }
    }
    return rows
}

function build(profile, firmware, port, instance, baud, injection, hasSeptentrioDriver, powerOptions) {
    var rows = []
    // Installation/fusion guides deliberately never fall through to a GPS recipe.
    if (!profile) return rows
    if (profile.requiresVerification) return installationRecipe(profile, firmware, port, instance, baud, powerOptions || {})
    function add(names, value, note, optional, orMask) {
        rows.push({ names: names, value: value, note: note, optional: !!optional, orMask: orMask || 0 })
    }
    if (firmware !== "ap" && firmware !== "px4") return rows
    if (isElrs(profile)) {
        var elrsMavlink = profile.kind === "elrs-mavlink"
        if (firmware === "ap") {
            if (!/^SERIAL[1-8]$/.test(port)) return rows
            add([port + "_PROTOCOL"], elrsMavlink ? 2 : 23, elrsMavlink ? "ELRS MAVLink2 数据 / 遥控" : "CRSF 遥控输入，波特率由驱动控制")
            add([port + "_OPTIONS"], 0, "完整双工、非反相、无 RX/TX 交换；保留其他串口选项")
            rows[rows.length - 1].clearMask = 15
            add(["RSSI_TYPE"], elrsMavlink ? 5 : 3, "按实际接收协议读取链路质量")
            if (elrsMavlink) add([port + "_BAUD"], 460, "ELRS MAVLink 官方默认 460800；接收机端须一致")
            else {
                add(["RC_OPTIONS"], 8192, "启用 ELRS 420 kbaud，保留其余选项位", false, 8192)
                add(["RC_PROTOCOLS"], 512, "自动识别保持不变；已有协议掩码时追加 CRSF", true, 512)
                rows[rows.length - 1].preserveZero = true
            }
        } else if (elrsMavlink) {
            add(["MAV_1_CONFIG"], px4Ports[port], "使用空闲 MAVLink 实例 1")
            add([px4BaudNames[port]], 460800, "与 ELRS 接收机串口速率一致")
            add(["MAV_1_MODE"], 0, "Normal 遥测模式")
            add(["MAV_1_RATE"], 9600, "ELRS 官方建议的 MAVLink 发送字节率")
        } else {
            add(["RC_CRSF_PRT_CFG"], px4Ports[port], "含 CRSF 驱动的 PX4 固件所用 UART")
            add(["RC_CRSF_TEL_EN"], 1, "开启接收机回传遥测；无需设置 UART 波特率")
        }
        return rows
    }
    if (profile.kind === "range-i2c") {
        if (firmware === "ap") {
            add(["RNGFND" + instance + "_TYPE"], profile.apType, "所选 I²C 激光测距驱动")
            if (profile.address !== undefined) add(["RNGFND" + instance + "_ADDR"], profile.address, "默认十进制地址；模块更改过地址时请先核对")
        } else if (profile.px4Enable) add([profile.px4Enable], profile.px4Value, "PX4 I²C 测距驱动")
        return rows
    }
    if (isPower(profile)) {
        if (instance !== 1 && instance !== 2) return rows
        var options = powerOptions || {}
        if (profile.kind === "power-can") {
            if (port !== "CAN1" && port !== "CAN2") return rows
            if (firmware === "ap") {
                var physical = port === "CAN2" ? 2 : 1
                var driver = options.canDriver === 1 || options.canDriver === 2 ? options.canDriver : physical
                add(["CAN_D" + driver + "_PROTOCOL"], 1, "DroneCAN 协议；不可覆盖已用于其他协议的 CAN 总线")
                add(["CAN_P" + physical + "_DRIVER"], driver, "只配置所选 CAN 口，保留已有有效驱动分配")
                add(batteryNames(instance, "MONITOR"), 8, "所选电池实例使用 DroneCAN 电压/电流监测；重启生效")
                if (profile.ignoreSoc) add(batteryNames(instance, "OPTIONS"), 1, "Holybro 建议忽略模块 SOC，保留其他选项位", true, 1)
            } else {
                add(["UAVCAN_ENABLE"], 2, "启用传感器及节点分配，不降低已有 CAN 电调模式")
                rows[rows.length - 1].minimumValue = true
                add(["UAVCAN_SUB_BAT"], 2, "订阅并过滤 DroneCAN 电池数据，需要支持的 PX4 固件")
                add(["BAT" + instance + "_SOURCE"], 1, "电池数据来自外部模块，节点与电池实例须核对")
            }
        } else if (profile.kind === "power-analog") {
            if (firmware === "ap") {
                var pins = analogPins[options.board]
                if (!pins || !pins[instance - 1] || (options.board === 4 && profile.amps !== 24)) return rows
                add(batteryNames(instance, "MONITOR"), 4, "模拟电压与电流，不适用于名称带 D 的数字模块")
                add(batteryNames(instance, "VOLT_PIN"), pins[instance - 1][0], "按飞控和 POWER 实例设置电压 ADC 引脚")
                add(batteryNames(instance, "CURR_PIN"), pins[instance - 1][1], "按飞控和 POWER 实例设置电流 ADC 引脚")
                add(batteryNames(instance, "VOLT_MULT"), profile.divider, "厂商标称分压比，必须用万用表核对实测电压")
                add(batteryNames(instance, "AMP_PERVLT"), profile.amps, "厂商标称 A/V，需要负载实测校准")
            } else {
                add(["BAT" + instance + "_SOURCE"], 0, "仅用于具备相应 ADC 接口的飞控模拟电源模块")
                add(["BAT" + instance + "_V_DIV"], profile.divider, "厂商标称电压分压比，实测后可微调")
                add(["BAT" + instance + "_A_PER_V"], profile.amps, "厂商标称安培/伏，不修改板级 ADC 驱动")
            }
        } else if (firmware === "ap") {
            add(batteryNames(instance, "MONITOR"), 21, "INA2xx 数字电源监测，需兼容的 I²C POWER 接口")
            add(batteryNames(instance, "I2C_BUS"), 1, "Holybro Pixhawk 5X / 6X 外部 I²C 总线")
            add(batteryNames(instance, "I2C_ADDR"), 0, "ArduPilot 4.4+ 自动寻址，旧固件请手动核对地址")
        }
        return rows
    }
    if (firmware === "px4" && profile.kind !== "can" && !(port in px4Ports)) return rows
    if (profile.kind === "flow") {
        if (firmware === "ap") {
            var flowSerial = /^SERIAL([1-8])$/.exec(port)
            if (!flowSerial) return rows
            var flowPrefix = "SERIAL" + flowSerial[1]
            add([flowPrefix + "_BAUD"], 115, "微空串口固定为 115200；模块使用 AUTO / Mavlink_apm 协议")
            add([flowPrefix + "_PROTOCOL"], 1, "微空官方指定 MAVLink1（不是普通 MAVLink2 数传）")
            if (powerOptions && powerOptions.modernMavOptions) {
                add(["MAV" + powerOptions.mavInstance + "_OPTIONS", "MAV_" + powerOptions.mavInstance + "_OPTIONS"], 2, "AP 4.7+：实际 MAVLink 通道禁止转发，保留其他位", false, 2)
            } else if (!powerOptions || !powerOptions.legacyFlow) add([flowPrefix + "_OPTIONS"], 1024, "4.5+ 添加禁止转发位，保留其他选项；缺少能力时禁止应用", false, 1024)
            add(["FLOW_TYPE"], 5, "MAVLink 光流；固件须编译光流功能")
            add(["RNGFND1_TYPE"], 10, "MAVLink 测距")
            add(["RNGFND1_ORIENT"], 25, "仅适用于已确认向下安装的测距传感器")
            add(["RNGFND1_MIN", "RNGFND1_MIN_CM"], 0.02, "量程下限 0.02 米；光流本身须离地至少 0.08 米")
            rows[rows.length - 1].centimeterAlias = true
            add(["RNGFND1_MAX", "RNGFND1_MAX_CM"], profile.maxRange, "按型号给出保守量程（米）；实际反射率和光照可能缩短可用距离")
            rows[rows.length - 1].centimeterAlias = true
        } else {
            add(["MAV_1_CONFIG"], px4Ports[port], "使用空闲的 MAVLink 实例 1 接收微空数据；模块使用 AUTO / Mavlink_px4")
            add(["MAV_1_MODE"], 0, "Normal 模式")
            add(["MAV_1_FORWARD"], 0, "禁止转发模块数据", true)
            add([px4BaudNames[port]], 115200, "微空模块固定 115200 8N1")
            if (powerOptions && powerOptions.flowFusion) {
                if (powerOptions.modernFlow) {
                    add(["EKF2_OF_CTRL"], 1, "启用光流融合；适用于提供该参数的固件")
                    add(["EKF2_RNG_CTRL"], 1, "启用条件式测距辅助")
                    add(["EKF2_HGT_REF"], 2, "高度参考改为下视测距，须核对使用环境")
                } else {
                    add(["EKF2_AID_MASK"], 2, "添加光流融合位，保留已有融合选项", false, 2)
                    add(["EKF2_RNG_AID"], 1, "旧固件测距辅助")
                    add(["EKF2_HGT_MODE"], 2, "旧固件高度源设为测距，须核对使用环境")
                }
            }
            if (powerOptions && powerOptions.flowMavlink1) add(["MAV_PROTO_VER"], 1, "厂商 PX4 1.17+ 兼容设置；会影响 MAVLink 协议协商，核对其他链路后应用")
        }
        // Navigation fusion is not a sensor-port recipe: never silently disable GPS
        // or replace the vehicle's EKF position/height/yaw sources.
        return rows
    }
    if (profile.kind === "can") {
        if (firmware === "ap") {
            var canPhysical = port === "CAN2" ? 2 : 1
            var canIndex = powerOptions && powerOptions.canDriver > 0 ? powerOptions.canDriver : canPhysical
            add(["CAN_D" + canIndex + "_PROTOCOL"], 1, "所选逻辑 CAN 驱动使用 DroneCAN")
            add(["CAN_P" + canPhysical + "_DRIVER"], canIndex, "所选物理 CAN 口保留已有逻辑驱动绑定")
            add(gpsNames(instance, "TYPE"), 9, "所选 GPS 实例使用 DroneCAN；多节点需另外核对节点分配")
            if (profile.led) add(["NTF_LED_TYPES"], 32, "添加 DroneCAN 状态灯位（bit 5），保留已有灯类型", true, 32)
        } else {
            add(["UAVCAN_ENABLE"], 2, "启用 DroneCAN 传感器和节点分配")
            rows[rows.length - 1].minimumValue = true
            add(["UAVCAN_SUB_GPS"], 1, "订阅 GNSS")
            if (profile.mag) add(["UAVCAN_SUB_MAG"], 1, "订阅磁力计", true)
            if (profile.rtcm) add(["UAVCAN_PUB_RTCM"], 1, "转发 RTCM 改正数据", true)
        }
    } else if (firmware === "ap") {
        var serial = /^SERIAL([1-8])$/.exec(port)
        if (!serial) return rows
        var prefix = "SERIAL" + serial[1]
        add([prefix + "_PROTOCOL"], profile.kind === "range" ? 9 : profile.kind === "telemetry" ? 2 : 5,
            profile.kind === "range" ? "串口测距仪" : profile.kind === "telemetry" ? "MAVLink2 数传；不要选择当前控制链路的接口" : "GPS 串口")
        add([prefix + "_BAUD"], baud === 230400 ? 230 : baud === 115200 ? 115 : baud === 57600 ? 57 : baud / 1000, "ArduPilot 波特率编码；必须与外设自身设置一致")
        if (profile.kind === "range") {
            add(["RNGFND" + instance + "_TYPE"], profile.apType, "启用所选实例的激光测距驱动；安装方向与有效量程按实际设置")
        } else if (profile.kind !== "telemetry") {
            var type = profile.kind === "sbf" ? 10 : profile.kind === "unicore" ? 24 : profile.kind === "nmea" ? 5 : 2
            add(gpsNames(instance, "TYPE"), type, "GPS" + instance + " 定位驱动；本方案不自动启用双天线航向")
            if (profile.kind === "sbf") add(gpsNames(instance, "RATE_MS"), 100, "10 Hz 定位更新", true)
        }
    } else if (profile.kind === "telemetry") {
        add(["MAV_1_CONFIG"], px4Ports[port], "使用空闲 MAVLink 实例 1；勿覆盖当前地面站链路")
        add(["MAV_1_MODE"], 0, "Normal 地面站遥测模式")
        add([px4BaudNames[port]], baud, "与 SiK / RFD 模块串口速率一致；不修改电台端参数")
    } else if (profile.kind === "range" && (profile.px4 || profile.px4Config)) {
        add([profile.px4Config || "SENS_TFMINI_CFG"], px4Ports[port], "所选激光测距驱动的实际物理串口")
        if (profile.px4Model !== undefined) add(["SENS_EN_SF0X"], profile.px4Model, "LightWare 实际型号")
        // PX4's TFmini driver hard-codes 115200; SER_*_BAUD does not control this driver.
    } else if (profile.kind !== "range" && profile.kind !== "telemetry") {
        if (profile.kind === "sbf" && hasSeptentrioDriver) {
            add(["SEP_PORT" + instance + "_CFG"], px4Ports[port], "新版 Septentrio 驱动：接收机实例与物理 GPS 端口不是同一个编号")
            // SEP_AUTO_CONFIG is deliberately not changed: preserve externally configured receiver settings.
        } else {
            add(["GPS_" + instance + "_CONFIG"], px4Ports[port], "GPS" + instance + " 实际物理接口")
            add(["GPS_" + instance + "_PROTOCOL"], profile.kind === "sbf" ? 7 : (profile.kind === "unicore" || profile.kind === "nmea") ? 6 : 1, "按固件现有 GPS 驱动选择协议")
        }
        add([px4BaudNames[port]], baud, "只修改所选物理接口的波特率")
    }
    if (firmware === "ap" && profile.rtcm) add(["GPS_INJECT_TO"], injection, "RTCM 注入目标：0=GPS1，1=GPS2，127=全部；不修改独立 RTK 接收机", true)
    return rows
}
