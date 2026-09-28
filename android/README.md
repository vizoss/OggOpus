# Android Demo 工程入口

在 Android Studio 中打开仓库的 **android 目录**，等待 Gradle 同步，选择 **sample** 模块，然后在 Android 设备上运行。

示例最低 API 23，提供运行时麦克风授权、录音、停止、播放和音量/时长显示。文件保存在应用内部 files 目录。示例直接依赖本仓库 `:oggopus` 模块。

构建环境：JDK 17（也可使用 Android Studio 内置 JDK）、Android SDK 34、NDK 28.0.12674087/CMake。固定 NDK r28，确保其自带的 `libc++_shared.so` 也支持 16 KB 对齐。从本目录执行：

```sh
./gradlew :sample:assembleDebug
```

APK 输出：`sample/build/outputs/apk/debug/sample-debug.apk`。模拟器可验证界面，麦克风录音和跨端互播应使用真机验收。

从仓库根目录执行 `bash scripts/check-android-16kb.sh android/sample/build/outputs/apk/debug/sample-debug.apk` 检查所有原生库的 ELF LOAD 对齐和 APK ZIP 对齐。设置 `ANDROID_HOME`，并安装 Build Tools 35.0.0。该检查不能替代 16 KB 设备上的录音播放测试。
