# Android 构建

工具版本集中在 `.github/build-config.json`。当前基线为 Qt 6.10.3、Android NDK 27.2.12479018、SDK API 36、Gradle 9.6.1（Wrapper 自动获取）、CMake、Ninja、Python 3 和支持当前 Android Gradle Plugin 的 JDK（建议 JDK 21）。Qt 组件包括 Quick、Quick Controls、Quick3D、Multimedia、Graphs、Location、Positioning、SerialPort、TextToSpeech、Bluetooth、HttpServer 等；按构建配置安装所需模块。

## 配置

克隆仓库并设置本机环境变量；以下为 PowerShell 示例，路径请换成自己安装的位置。

```powershell
$env:QT_ANDROID = "C:/Qt/6.10.3/android_arm64_v8a"
$env:QT_HOST_PATH = "C:/Qt/6.10.3/msvc2022_64"
$env:ANDROID_SDK_ROOT = "C:/Android/Sdk"
$env:ANDROID_NDK_ROOT = "$env:ANDROID_SDK_ROOT/ndk/27.2.12479018"
$env:JAVA_HOME = "C:/Java/jdk-21"
cmake -S . -B build-android -G Ninja `
  "-DCMAKE_TOOLCHAIN_FILE=$env:QT_ANDROID/lib/cmake/Qt6/qt.toolchain.cmake" `
  "-DQT_HOST_PATH=$env:QT_HOST_PATH" `
  "-DANDROID_SDK_ROOT=$env:ANDROID_SDK_ROOT" `
  "-DANDROID_NDK_ROOT=$env:ANDROID_NDK_ROOT" `
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-28 `
  -DCMAKE_BUILD_TYPE=Release -DQGC_BUILD_TESTING=OFF
cmake --build build-android --target apk --parallel 2
```

Windows 需要准备相应的 Qt 主机工具和工具链环境；Linux 主机可使用相应 Linux Qt 主机包。CMake 会获取项目固定的第三方依赖，首次构建需要网络，资源使用较多。可通过 `CPM_SOURCE_CACHE` 指定自己准备的缓存，不依赖维护者的缓存目录。

## 签名与分发

构建得到的未签名 APK 位于构建目录的 `android-build` 下。用 Android SDK 的 `zipalign -P 16` 和 `apksigner` 按 Android 官方流程签名。创建并妥善保管自己的密钥，勿提交私钥或密码。第三方修改版使用自己的包名和签名，并说明维护者身份。

正式发行同时提供本次构建对应的源码、许可证和修改说明。设备测试结果与已知限制应写入发行说明；未经验证的构建不应宣称通过实机飞行测试。
