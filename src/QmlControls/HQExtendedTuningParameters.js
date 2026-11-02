.pragma library

// Both the Fly View tool and the fixed setup page use this catalogue. Names
// identify real vehicle Facts, newest first; they are not stored parameters.
// Always display/write the selected Fact's cooked value and units. ArduPilot
// 4.7 renamed parameters AND changed units/gain scales; do not copy or scale a
// value from one alias to another in the UI.
// References:
// https://github.com/ArduPilot/ardupilot/blob/Copter-4.7.0/libraries/AC_WPNav/AC_WPNav.cpp
// https://github.com/ArduPilot/ardupilot/blob/Copter-4.7.0/libraries/AC_WPNav/AC_Loiter.cpp
// https://github.com/ArduPilot/ardupilot/blob/Copter-4.7.0/libraries/AC_AttitudeControl/AC_PosControl.cpp
// https://ardupilot.org/copter/docs/common-param-name-changes.html
// https://github.com/ArduPilot/ardupilot/blob/Copter-4.6.3/libraries/AC_AttitudeControl/AC_PosControl.cpp
// https://ardupilot.org/copter/docs/common-imu-notch-filtering.html
// https://docs.px4.io/main/en/advanced_config/parameter_reference
function sections() {
    return [
        { key: "apm-attitude", firmware: "apm", title: qsTranslate("HQExtendedTuning", "自稳角度与输入"), params: [
            { label: qsTranslate("HQExtendedTuning", "横滚角度 P"), names: ["ATC_ANG_RLL_P"] },
            { label: qsTranslate("HQExtendedTuning", "俯仰角度 P"), names: ["ATC_ANG_PIT_P"] },
            { label: qsTranslate("HQExtendedTuning", "偏航角度 P"), names: ["ATC_ANG_YAW_P"] },
            { label: qsTranslate("HQExtendedTuning", "输入时间常数"), names: ["ATC_INPUT_TC"] },
            { label: qsTranslate("HQExtendedTuning", "横滚最大加速度"), names: ["ATC_ACC_R_MAX", "ATC_ACCEL_R_MAX"] },
            { label: qsTranslate("HQExtendedTuning", "俯仰最大加速度"), names: ["ATC_ACC_P_MAX", "ATC_ACCEL_P_MAX"] },
            { label: qsTranslate("HQExtendedTuning", "偏航最大加速度"), names: ["ATC_ACC_Y_MAX", "ATC_ACCEL_Y_MAX"] }
        ]},
        { key: "apm-roll-rate", firmware: "apm", title: qsTranslate("HQExtendedTuning", "横滚速率 PID / 滤波"), params: [
            { label: "P", names: ["ATC_RAT_RLL_P"] }, { label: "I", names: ["ATC_RAT_RLL_I"] },
            { label: "D", names: ["ATC_RAT_RLL_D"] }, { label: qsTranslate("HQExtendedTuning", "I 最大"), names: ["ATC_RAT_RLL_IMAX"] },
            { label: qsTranslate("HQExtendedTuning", "前馈 FF"), names: ["ATC_RAT_RLL_FF"] },
            { label: qsTranslate("HQExtendedTuning", "误差滤波 FLTE / Hz"), names: ["ATC_RAT_RLL_FLTE"] },
            { label: qsTranslate("HQExtendedTuning", "微分滤波 FLTD / Hz"), names: ["ATC_RAT_RLL_FLTD"] },
            { label: qsTranslate("HQExtendedTuning", "目标滤波 FLTT / Hz"), names: ["ATC_RAT_RLL_FLTT"] }
        ]},
        { key: "apm-pitch-rate", firmware: "apm", title: qsTranslate("HQExtendedTuning", "俯仰速率 PID / 滤波"), params: [
            { label: "P", names: ["ATC_RAT_PIT_P"] }, { label: "I", names: ["ATC_RAT_PIT_I"] },
            { label: "D", names: ["ATC_RAT_PIT_D"] }, { label: qsTranslate("HQExtendedTuning", "I 最大"), names: ["ATC_RAT_PIT_IMAX"] },
            { label: qsTranslate("HQExtendedTuning", "前馈 FF"), names: ["ATC_RAT_PIT_FF"] },
            { label: qsTranslate("HQExtendedTuning", "误差滤波 FLTE / Hz"), names: ["ATC_RAT_PIT_FLTE"] },
            { label: qsTranslate("HQExtendedTuning", "微分滤波 FLTD / Hz"), names: ["ATC_RAT_PIT_FLTD"] },
            { label: qsTranslate("HQExtendedTuning", "目标滤波 FLTT / Hz"), names: ["ATC_RAT_PIT_FLTT"] }
        ]},
        { key: "apm-yaw-rate", firmware: "apm", title: qsTranslate("HQExtendedTuning", "偏航速率 PID / 滤波"), params: [
            { label: "P", names: ["ATC_RAT_YAW_P"] }, { label: "I", names: ["ATC_RAT_YAW_I"] },
            { label: "D", names: ["ATC_RAT_YAW_D"] }, { label: qsTranslate("HQExtendedTuning", "I 最大"), names: ["ATC_RAT_YAW_IMAX"] },
            { label: qsTranslate("HQExtendedTuning", "前馈 FF"), names: ["ATC_RAT_YAW_FF"] },
            { label: qsTranslate("HQExtendedTuning", "误差滤波 FLTE / Hz"), names: ["ATC_RAT_YAW_FLTE"] },
            { label: qsTranslate("HQExtendedTuning", "微分滤波 FLTD / Hz"), names: ["ATC_RAT_YAW_FLTD"] },
            { label: qsTranslate("HQExtendedTuning", "目标滤波 FLTT / Hz"), names: ["ATC_RAT_YAW_FLTT"] }
        ]},
        { key: "apm-horizontal-position", firmware: "apm", title: qsTranslate("HQExtendedTuning", "位置 XY 环"), params: [
            { label: qsTranslate("HQExtendedTuning", "位置 XY P"), names: ["PSC_NE_POS_P", "PSC_POSXY_P"] }
        ]},
        // AC_PID_2D reports FLTE and FLTD; it has no FLTT target filter.
        // IMAX changed from cm/s² to m/s² in 4.7: use the selected Fact unchanged.
        { key: "apm-horizontal-velocity", firmware: "apm", title: qsTranslate("HQExtendedTuning", "速度 XY 环 PID / 滤波"), params: [
            { label: "P", names: ["PSC_NE_VEL_P", "PSC_VELXY_P"] },
            { label: "I", names: ["PSC_NE_VEL_I", "PSC_VELXY_I"] },
            { label: "D", names: ["PSC_NE_VEL_D", "PSC_VELXY_D"] },
            { label: qsTranslate("HQExtendedTuning", "I 最大"), names: ["PSC_NE_VEL_IMAX", "PSC_VELXY_IMAX"] },
            { label: qsTranslate("HQExtendedTuning", "前馈 FF"), names: ["PSC_NE_VEL_FF", "PSC_VELXY_FF"] },
            { label: qsTranslate("HQExtendedTuning", "误差滤波 FLTE / Hz"), names: ["PSC_NE_VEL_FLTE", "PSC_VELXY_FLTE"] },
            { label: qsTranslate("HQExtendedTuning", "微分滤波 FLTD / Hz"), names: ["PSC_NE_VEL_FLTD", "PSC_VELXY_FLTD"] }
        ]},
        { key: "apm-vertical", firmware: "apm", title: qsTranslate("HQExtendedTuning", "高度与油门"), params: [
            { label: qsTranslate("HQExtendedTuning", "油门加速度 P"), names: ["PSC_D_ACC_P", "PSC_ACCZ_P", "ACCEL_Z_P"] },
            { label: qsTranslate("HQExtendedTuning", "油门加速度 I"), names: ["PSC_D_ACC_I", "PSC_ACCZ_I", "ACCEL_Z_I"] },
            { label: qsTranslate("HQExtendedTuning", "油门加速度 D"), names: ["PSC_D_ACC_D", "PSC_ACCZ_D", "ACCEL_Z_D"] },
            { label: qsTranslate("HQExtendedTuning", "油门加速度 I 最大"), names: ["PSC_D_ACC_IMAX", "PSC_ACCZ_IMAX", "ACCEL_Z_IMAX"] },
            { label: qsTranslate("HQExtendedTuning", "垂直速度 P"), names: ["PSC_D_VEL_P", "PSC_VELZ_P", "VEL_Z_P"] },
            { label: qsTranslate("HQExtendedTuning", "高度保持 P"), names: ["PSC_D_POS_P", "PSC_POSZ_P", "POS_Z_P"] }
        ]},
        { key: "apm-navigation", firmware: "apm", title: qsTranslate("HQExtendedTuning", "航点导航"), params: [
            { label: qsTranslate("HQExtendedTuning", "水平速度"), names: ["WP_SPD", "WPNAV_SPEED"] },
            { label: qsTranslate("HQExtendedTuning", "航点半径"), names: ["WP_RADIUS_M", "WPNAV_RADIUS"] },
            { label: qsTranslate("HQExtendedTuning", "上升速度"), names: ["WP_SPD_UP", "WPNAV_SPEED_UP"] },
            { label: qsTranslate("HQExtendedTuning", "下降速度"), names: ["WP_SPD_DN", "WPNAV_SPEED_DN"] },
            { label: qsTranslate("HQExtendedTuning", "水平加速度"), names: ["WP_ACC", "WPNAV_ACCEL"] },
            { label: qsTranslate("HQExtendedTuning", "垂直加速度"), names: ["WP_ACC_Z", "WPNAV_ACCEL_Z"] },
            { label: qsTranslate("HQExtendedTuning", "转弯加速度"), names: ["WP_ACC_CNR", "WPNAV_ACCEL_C"] },
            { label: qsTranslate("HQExtendedTuning", "Loiter 最大水平速度"), names: ["LOIT_SPEED_MS", "LOIT_SPEED", "WPNAV_LOIT_SPEED"] }
        ]},
        { key: "apm-basic-filters", firmware: "apm", title: qsTranslate("HQExtendedTuning", "基础与日志滤波"), params: [
            { label: qsTranslate("HQExtendedTuning", "陀螺低通"), names: ["INS_GYRO_FILTER"] },
            { label: qsTranslate("HQExtendedTuning", "加速度计低通"), names: ["INS_ACCEL_FILTER"] },
            { label: qsTranslate("HQExtendedTuning", "滤波日志掩码"), names: ["INS_LOG_BAT_MASK"] },
            { label: qsTranslate("HQExtendedTuning", "滤波日志选项"), names: ["INS_LOG_BAT_OPT"] }
        ]},
        { key: "apm-static-notch", firmware: "apm", title: qsTranslate("HQExtendedTuning", "静态陷波器"),
          gate: ["INS_NOTCH_ENABLE"], staticLegacy: true,
          hint: qsTranslate("HQExtendedTuning", "本固件未提供旧式静态陷波参数时，可检查谐波陷波的固定频率模式（MODE=0）；不会自动启用或切换模式。"),
          params: [
            { label: qsTranslate("HQExtendedTuning", "启用"), names: ["INS_NOTCH_ENABLE"] },
            { label: qsTranslate("HQExtendedTuning", "频率"), names: ["INS_NOTCH_FREQ"] },
            { label: qsTranslate("HQExtendedTuning", "带宽"), names: ["INS_NOTCH_BW"] },
            { label: qsTranslate("HQExtendedTuning", "衰减"), names: ["INS_NOTCH_ATT"] }
        ]},
        { key: "apm-harmonic-notch", firmware: "apm", title: qsTranslate("HQExtendedTuning", "谐波陷波器"),
          gate: ["INS_HNTCH_ENABLE"],
          hint: qsTranslate("HQExtendedTuning", "启用并确认写入后，请重启飞控并重新读取参数，以显示详细设置。频率与跟踪模式应根据实际日志和转速来源选择。"),
          params: [
            { label: qsTranslate("HQExtendedTuning", "启用"), names: ["INS_HNTCH_ENABLE"] },
            { label: qsTranslate("HQExtendedTuning", "模式"), names: ["INS_HNTCH_MODE"] },
            { label: qsTranslate("HQExtendedTuning", "频率"), names: ["INS_HNTCH_FREQ"] },
            { label: qsTranslate("HQExtendedTuning", "带宽"), names: ["INS_HNTCH_BW"] },
            { label: qsTranslate("HQExtendedTuning", "衰减"), names: ["INS_HNTCH_ATT"] },
            { label: qsTranslate("HQExtendedTuning", "参考值"), names: ["INS_HNTCH_REF"] },
            { label: qsTranslate("HQExtendedTuning", "谐波掩码"), names: ["INS_HNTCH_HMNCS"] },
            { label: qsTranslate("HQExtendedTuning", "选项"), names: ["INS_HNTCH_OPTS"] }
        ]},
        // This optional bank is available only if the flight controller reports
        // its gate or child Facts. Do not fabricate it for trimmed firmware.
        { key: "apm-harmonic-notch-2", firmware: "apm", title: qsTranslate("HQExtendedTuning", "第二组谐波陷波器"),
          gate: ["INS_HNTC2_ENABLE"],
          hint: qsTranslate("HQExtendedTuning", "仅在飞控提供第二组陷波参数时可配置。启用并确认写入后，请重启并重新读取参数；额外陷波会增加处理负载。"),
          params: [
            { label: qsTranslate("HQExtendedTuning", "启用"), names: ["INS_HNTC2_ENABLE"] },
            { label: qsTranslate("HQExtendedTuning", "模式"), names: ["INS_HNTC2_MODE"] },
            { label: qsTranslate("HQExtendedTuning", "频率"), names: ["INS_HNTC2_FREQ"] },
            { label: qsTranslate("HQExtendedTuning", "带宽"), names: ["INS_HNTC2_BW"] },
            { label: qsTranslate("HQExtendedTuning", "衰减"), names: ["INS_HNTC2_ATT"] },
            { label: qsTranslate("HQExtendedTuning", "参考值"), names: ["INS_HNTC2_REF"] },
            { label: qsTranslate("HQExtendedTuning", "谐波掩码"), names: ["INS_HNTC2_HMNCS"] },
            { label: qsTranslate("HQExtendedTuning", "选项"), names: ["INS_HNTC2_OPTS"] }
        ]},
        { key: "px4-attitude", firmware: "px4", title: qsTranslate("HQExtendedTuning", "PX4 姿态控制"), params: [
            { label: qsTranslate("HQExtendedTuning", "横滚角度 P"), names: ["MC_ROLL_P"] },
            { label: qsTranslate("HQExtendedTuning", "俯仰角度 P"), names: ["MC_PITCH_P"] },
            { label: qsTranslate("HQExtendedTuning", "偏航角度 P"), names: ["MC_YAW_P"] },
            { label: qsTranslate("HQExtendedTuning", "偏航权重"), names: ["MC_YAW_WEIGHT"] },
            { label: qsTranslate("HQExtendedTuning", "偏航扭矩滤波"), names: ["MC_YAW_TQ_CUTOFF"] }
        ]},
        { key: "px4-roll-rate", firmware: "px4", title: qsTranslate("HQExtendedTuning", "PX4 横滚速率 PID"), params: [
            { label: qsTranslate("HQExtendedTuning", "总增益 K"), names: ["MC_ROLLRATE_K"] },
            { label: "P", names: ["MC_ROLLRATE_P"] }, { label: "I", names: ["MC_ROLLRATE_I"] },
            { label: "D", names: ["MC_ROLLRATE_D"] },
            { label: qsTranslate("HQExtendedTuning", "前馈 FF"), names: ["MC_ROLLRATE_FF"] },
            { label: qsTranslate("HQExtendedTuning", "最大速率"), names: ["MC_ROLLRATE_MAX"] }
        ]},
        { key: "px4-pitch-rate", firmware: "px4", title: qsTranslate("HQExtendedTuning", "PX4 俯仰速率 PID"), params: [
            { label: qsTranslate("HQExtendedTuning", "总增益 K"), names: ["MC_PITCHRATE_K"] },
            { label: "P", names: ["MC_PITCHRATE_P"] }, { label: "I", names: ["MC_PITCHRATE_I"] },
            { label: "D", names: ["MC_PITCHRATE_D"] },
            { label: qsTranslate("HQExtendedTuning", "前馈 FF"), names: ["MC_PITCHRATE_FF"] },
            { label: qsTranslate("HQExtendedTuning", "最大速率"), names: ["MC_PITCHRATE_MAX"] }
        ]},
        { key: "px4-yaw-rate", firmware: "px4", title: qsTranslate("HQExtendedTuning", "PX4 偏航速率 PID"), params: [
            { label: qsTranslate("HQExtendedTuning", "总增益 K"), names: ["MC_YAWRATE_K"] },
            { label: "P", names: ["MC_YAWRATE_P"] }, { label: "I", names: ["MC_YAWRATE_I"] },
            { label: "D", names: ["MC_YAWRATE_D"] },
            { label: qsTranslate("HQExtendedTuning", "前馈 FF"), names: ["MC_YAWRATE_FF"] },
            { label: qsTranslate("HQExtendedTuning", "最大速率"), names: ["MC_YAWRATE_MAX"] }
        ]},
        { key: "px4-position", firmware: "px4", title: qsTranslate("HQExtendedTuning", "PX4 位置与速度控制"), params: [
            { label: qsTranslate("HQExtendedTuning", "水平位置 P"), names: ["MPC_XY_P"] },
            { label: qsTranslate("HQExtendedTuning", "高度位置 P"), names: ["MPC_Z_P"] },
            { label: qsTranslate("HQExtendedTuning", "水平速度 P"), names: ["MPC_XY_VEL_P_ACC"] },
            { label: qsTranslate("HQExtendedTuning", "水平速度 I"), names: ["MPC_XY_VEL_I_ACC"] },
            { label: qsTranslate("HQExtendedTuning", "水平速度 D"), names: ["MPC_XY_VEL_D_ACC"] },
            { label: qsTranslate("HQExtendedTuning", "垂直速度 P"), names: ["MPC_Z_VEL_P_ACC"] },
            { label: qsTranslate("HQExtendedTuning", "垂直速度 I"), names: ["MPC_Z_VEL_I_ACC"] },
            { label: qsTranslate("HQExtendedTuning", "垂直速度 D"), names: ["MPC_Z_VEL_D_ACC"] }
        ]},
        { key: "px4-motion-limits", firmware: "px4", title: qsTranslate("HQExtendedTuning", "PX4 速度与加速度限制"), params: [
            { label: qsTranslate("HQExtendedTuning", "巡航速度"), names: ["MPC_XY_CRUISE"] },
            { label: qsTranslate("HQExtendedTuning", "最大水平速度"), names: ["MPC_XY_VEL_MAX"] },
            { label: qsTranslate("HQExtendedTuning", "自动上升速度"), names: ["MPC_Z_V_AUTO_UP"] },
            { label: qsTranslate("HQExtendedTuning", "自动下降速度"), names: ["MPC_Z_V_AUTO_DN"] },
            { label: qsTranslate("HQExtendedTuning", "水平加速度"), names: ["MPC_ACC_HOR"] },
            { label: qsTranslate("HQExtendedTuning", "最大水平加速度"), names: ["MPC_ACC_HOR_MAX"] },
            { label: qsTranslate("HQExtendedTuning", "最大上升加速度"), names: ["MPC_ACC_UP_MAX"] },
            { label: qsTranslate("HQExtendedTuning", "最大下降加速度"), names: ["MPC_ACC_DOWN_MAX"] },
            { label: qsTranslate("HQExtendedTuning", "自动任务加加速度"), names: ["MPC_JERK_AUTO"] },
            { label: qsTranslate("HQExtendedTuning", "最大加加速度"), names: ["MPC_JERK_MAX"] }
        ]},
        // Do not gate this whole section on IMU_GYRO_DNF_EN: low-pass and static
        // notch settings remain independently available. DNF_EN is a bitmask,
        // not a boolean: bit 0 selects ESC RPM, bit 1 selects FFT (values 0..3).
        { key: "px4-imu-filters", firmware: "px4", title: qsTranslate("HQExtendedTuning", "PX4 IMU 与陷波滤波"),
          hint: qsTranslate("HQExtendedTuning", "静态陷波频率为 0 时关闭。动态陷波启用是来源位掩码：ESC 转速或 FFT，可同时选择；需要实际转速反馈或机载 FFT 支持。"),
          params: [
            { label: qsTranslate("HQExtendedTuning", "陀螺低通"), names: ["IMU_GYRO_CUTOFF"] },
            { label: qsTranslate("HQExtendedTuning", "D 项陀螺低通"), names: ["IMU_DGYRO_CUTOFF"] },
            { label: qsTranslate("HQExtendedTuning", "加速度计低通"), names: ["IMU_ACCEL_CUTOFF"] },
            { label: qsTranslate("HQExtendedTuning", "静态陷波 1 频率"), names: ["IMU_GYRO_NF0_FRQ"] },
            { label: qsTranslate("HQExtendedTuning", "静态陷波 1 带宽"), names: ["IMU_GYRO_NF0_BW"] },
            { label: qsTranslate("HQExtendedTuning", "静态陷波 2 频率"), names: ["IMU_GYRO_NF1_FRQ"] },
            { label: qsTranslate("HQExtendedTuning", "静态陷波 2 带宽"), names: ["IMU_GYRO_NF1_BW"] },
            { label: qsTranslate("HQExtendedTuning", "动态陷波启用"), names: ["IMU_GYRO_DNF_EN"] },
            { label: qsTranslate("HQExtendedTuning", "动态陷波最小频率"), names: ["IMU_GYRO_DNF_MIN"] },
            { label: qsTranslate("HQExtendedTuning", "动态陷波带宽"), names: ["IMU_GYRO_DNF_BW"] },
            { label: qsTranslate("HQExtendedTuning", "动态陷波谐波数"), names: ["IMU_GYRO_DNF_HMC"] }
        ]},
        { key: "px4-thrust", firmware: "px4", title: qsTranslate("HQExtendedTuning", "PX4 推力与控制模式"), params: [
            { label: qsTranslate("HQExtendedTuning", "空气模式"), names: ["MC_AIRMODE"] },
            { label: qsTranslate("HQExtendedTuning", "推力模型系数"), names: ["THR_MDL_FAC"] },
            { label: qsTranslate("HQExtendedTuning", "位置控制模式"), names: ["MPC_POS_MODE"] }
        ]}
    ];
}
