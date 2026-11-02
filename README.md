# HDZX Android · 安卓开源地面站

<img src="resources/branding/HDZXLogo.png" alt="HDZX" width="88">

**面向 ArduPilot 与 PX4 的中文安卓地面站，基于 QGroundControl 开发。**

HDZX Android 为手机和平板提供飞行状态查看、航线规划、参数调试和日志分析等工具。项目由段中旭工作室维护；此仓库是独立整理的安卓开源版。

> This is an Android-focused, Chinese-localized ground station derived from QGroundControl. It is maintained independently and is not an official QGroundControl release.

## 功能介绍

| 功能 | 说明 |
|---|---|
| 飞控连接 | 串口／USB、UDP、TCP 等 MAVLink 连接；提供手动连接入口和连接状态提示。实际接口取决于安卓设备和驱动。 |
| 飞行视图 | 飞行模式、定位、电池、速度、高度与链路状态；二维地图和三维地形视图、轨迹及 Home 点标识。地图与地形可用性取决于数据源和网络。 |
| 经典飞行 HUD | 姿态、航向和基础飞行信息，定位解算状态，以及 EKF／振动诊断入口；支持调整大小、移动和收起。 |
| 航线规划 | 手动航点编辑、任务文件读写和任务预览。上传前请核对坐标、高度参考系和任务内容。 |
| PID 响应 | 按飞控提供的遥测查看角速度、姿态、位置和速度环；支持选择轴、刷新频率和可用曲线。未回传的目标或 PID 分量不构造假数据。 |
| 扩展调参 | 分组显示当前固件实际提供的参数；编辑后确认提交，保留原生参数表。 |
| 外设配置建议 | 常见 GNSS、光流、测距及接收机的参数预览与应用；按固件实际参数匹配，安装偏移等实测项需自行确认。 |
| 双语告警与语音 | 查看飞控原始报错及已有中文解释、解决建议；中文／英文录音提示、模式切换和 RTK 状态变化提醒。未收录消息保留原文。 |
| 飞行仪表盘 | 可调整显示的飞行仪表和基础数据。 |
| 日志与分析 | 日志查看、参数与飞行数据分析；AI 调参／日志分析辅助需要用户自行配置服务与密钥，并会把所选分析内容发送给配置的服务。 |
| 图传 | 保留普通飞行图传入口；来源、解码与硬件支持取决于构建选项和设备。 |
| 移动端适配 | 手机／平板界面比例调整、触摸侧边栏和可打断的页面／面板切换动画。 |

功能随飞控、固件版本、遥测消息和外设而异。参数修改及飞行动作应在确认条件后操作；辅助分析不代替飞行员判断。

## 下载与安装

在 [Releases](https://github.com/duan816/HDZX-Android/releases) 下载带版本号的安卓 APK。官方开源版应用 ID 为 `org.hquavcenter.hdzx.opensource`，与其他发行版分开保存应用数据。

- 本项目 Android 最低 API 为 28（Android 9），首个发布包面向 arm64-v8a。
- USB 连接需要设备支持 USB Host／OTG，并授予应用 USB 访问权限。
- 首次使用先选择手机或平板显示比例，随后可在“应用设置”中调整。
- 密钥、飞控连接配置和地图服务凭据请自行设置；源码不包含维护者私钥或第三方账号凭据。

## 二次开发

参见 [Android 构建指南](docs/BUILD_ANDROID.md)、[开发约定](AGENTS.md) 和 [贡献指南](CONTRIBUTING.md)。本仓库包含实际构建使用的源码及资源，构建工具链与第三方依赖通过各自渠道获取。

## 来源、许可证与品牌

- 上游项目：[QGroundControl](https://github.com/mavlink/qgroundcontrol)。上游作者、版权与许可声明予以保留，参见 [上游许可说明](.github/COPYING.md)。
- HDZX 新增／修改部分按 **GNU GPL v3** 发布；本组合发行版选择 GPLv3，见 [LICENSE](LICENSE)。第三方文件保留各自许可，详情见 [NOTICE](NOTICE) 和 [来源说明](docs/PROVENANCE.md)、[依赖与源码获取](docs/THIRD_PARTY.md)。
- 可以按相应许可证修改、分发和商业使用。分发时应履行源码提供、版权及许可声明、修改说明等适用义务。
- HDZX 名称和标识用于识别官方版本；衍生项目应清楚说明自己的维护者和修改，不能冒充官方。参见 [品牌使用规则](BRANDING.md)。品牌规则不增加代码许可证之外的使用领域或商业限制。

## 反馈

请通过 [Issues](https://github.com/duan816/HDZX-Android/issues) 反馈，并提供设备型号、Android 版本、应用版本、飞控／固件版本和复现步骤。公开日志前请删除坐标、飞行任务和个人信息等不愿公开的内容。
