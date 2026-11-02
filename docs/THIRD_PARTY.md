# 依赖、许可与源码获取

本仓库保留 QGroundControl 及原有文件的版权和许可。组合应用使用 GPLv3；各依赖仍按其各自许可提供。构建脚本中记录版本、Git 引用和下载校验；跟随分支的参数元数据可能随重新构建而更新。

## Qt 和图传

- **Qt 6.10.3**：所用模块与版本见 `.github/build-config.json`；[官方完整对应源码下载目录](https://download.qt.io/official_releases/qt/6.10/6.10.3/single/) 提供 `qt-everywhere-src-6.10.3.tar.xz` 和 ZIP。各模块的 LICENSES 与第三方声明须一并保留。
- **GStreamer Android 1.28.4**：版本、插件列表和 SDK 校验值见 `.github/build-config.json`、`cmake/GStreamer`；[官方源码目录](https://gstreamer.freedesktop.org/src/) 提供 GStreamer、gst-plugins-base/good/bad/ugly、gst-libav 等组件对应源码。[构建工具 Cerbero](https://gitlab.freedesktop.org/gstreamer/cerbero/-/tree/1.28.4) 中的配方记录其 SDK 依赖源码和构建方式。
- Android NDK／SDK 与 JDK 由各工具发行渠道提供，未作为本仓库中的二进制开发环境重新分发。

## CMake 下载的依赖

以下定位到实际构建脚本。使用脚本中版本获取源码和相应 LICENSE／COPYING／NOTICE；变量值可在对应文件与依赖配置中查找。未启用的平台或功能不会编入本 APK。

| 依赖 | 源码仓库 | 固定版本／引用 | 配置位置 |
|---|---|---|---|
| ArduPilotParams | [ArduPilot/ParameterRepository](https://github.com/ArduPilot/ParameterRepository) | `main` | `src/FirmwarePlugin/APM/CMakeLists.txt` |
| EXPAT | [libexpat/libexpat](https://github.com/libexpat/libexpat) | `R_2_7_5` | `src/Viewer3D/Providers/Osm/CMakeLists.txt` |
| LibLZMA | [tukaani-project/xz](https://github.com/tukaani-project/xz) | `v5.8.3` | `src/Utilities/Compression/CMakeLists.txt` |
| QtAndroidTools | [FalsinSoft/QtAndroidTools](https://github.com/FalsinSoft/QtAndroidTools) | `47ba0fcf75c91a4e3b01ee34f718bf59014892db` | `src/Android/CMakeLists.txt` |
| SDL3 | [libsdl-org/SDL](https://github.com/libsdl-org/SDL) | `release-3.4.2` | `src/Utilities/SDL/CMakeLists.txt` |
| Shapelib | [OSGeo/shapelib](https://github.com/OSGeo/shapelib) | `v1.6.3` | `src/Utilities/Geo/Formats/CMakeLists.txt` |
| VulkanHeaders | [KhronosGroup/Vulkan-Headers](https://github.com/KhronosGroup/Vulkan-Headers) | `vulkan-sdk-1.4.341.0` | `CMakeLists.txt` |
| ZLIB | [madler/zlib](https://github.com/madler/zlib) | `v1.3.2` | `src/Utilities/Compression/CMakeLists.txt` |
| earcut_hpp | [mapbox/earcut.hpp](https://github.com/mapbox/earcut.hpp) | `f36ced7e50254738c4e5af1a239f5fb7b1094007` | `src/Viewer3D/Providers/Osm/CMakeLists.txt` |
| geographiclib | [geographiclib/geographiclib](https://github.com/geographiclib/geographiclib) | `r2.7` | `src/Utilities/Geo/CMakeLists.txt` |
| libevents | [mavlink/libevents](https://github.com/mavlink/libevents) | `840a88ea226d4eb0fd4c391ce860317422756435` | `src/MAVLink/LibEvents/CMakeLists.txt` |
| libexif | [libexif/libexif](https://github.com/libexif/libexif) | `v${QGC_LIBEXIF_VERSION}` | `src/Utilities/Parsing/CMakeLists.txt` |
| libosmium | [osmcode/libosmium](https://github.com/osmcode/libosmium) | `v2.23.0` | `src/Viewer3D/Providers/Osm/CMakeLists.txt` |
| lz4 | [lz4/lz4](https://github.com/lz4/lz4) | `v1.10.0` | `src/Utilities/Compression/CMakeLists.txt` |
| protozero | [mapbox/protozero](https://github.com/mapbox/protozero) | `v1.8.1` | `src/Viewer3D/Providers/Osm/CMakeLists.txt` |
| px4-gpsdrivers | [PX4/PX4-GPSDrivers](https://github.com/PX4/PX4-GPSDrivers) | `cd6f506afda9bd6e8e4645f094dcf5415f1f8be4` | `src/GPS/Driver/CMakeLists.txt` |
| qtandroidextensions | [2gis/qtandroidextensions](https://github.com/2gis/qtandroidextensions) | `qt6-beta1` | `src/Android/CMakeLists.txt` |
| sdl_gamecontrollerdb | [mdqinc/SDL_GameControllerDB](https://github.com/mdqinc/SDL_GameControllerDB) | `513c72e34569e0f471dde7aa26eecb23946c3ef7` | `src/Utilities/SDL/CMakeLists.txt` |
| ulog_cpp | [PX4/ulog_cpp](https://github.com/PX4/ulog_cpp) | `v1.0.1` | `src/Utilities/Parsing/CMakeLists.txt` |
| valijson | [tristanpenman/valijson](https://github.com/tristanpenman/valijson) | `v1.1.0` | `src/Utilities/Parsing/CMakeLists.txt` |
| zstd | [facebook/zstd](https://github.com/facebook/zstd) | `v1.5.7` | `src/Utilities/Compression/CMakeLists.txt` |

MAVLink 仓库和提交由 `cmake/CustomOptions.cmake` 与 `src/MAVLink/CMakeLists.txt` 固定；Qt Android 扩展、串口 Java 驱动等来源见 `src/Android/CMakeLists.txt` 与 `cmake`。字体、图标、模型及其他原有资源保留原作者文件和声明；NanumGothic（OFL 1.1）和本仓库版本 OpenSans（Apache 2.0）的声明与许可随 APK 的 `android/assets/licenses` 打包；坐标转换组件的 MIT 许可见 `resources/licenses/coordtransform-MIT.txt`。

发布修改后的 APK 时，应同时提供对应应用源码、构建脚本、版本及依赖源码取得方式，并按实际所用组件的许可证附带声明。请勿把私钥、服务密钥或个人配置当作源码发布。
