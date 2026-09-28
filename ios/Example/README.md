# OggOpus Xcode Demo

直接打开本目录的 **OggOpusDemo.xcodeproj**，选择 **OggOpusDemo** scheme 和 iPhone 设备运行。工程通过本地 SPM 引用仓库根目录 SDK，首次打开会解析 Ogg/Opus 依赖。

真机运行时，在 Signing & Capabilities 中选择自己的 Team；最低 iOS 15。无需运行 CocoaPods 或 XcodeGen 即可打开已生成的工程。

Demo 使用 UIKit 场景生命周期（AppDelegate + SceneDelegate + UINavigationController + UIViewController），通过 Info.plist 注册场景并由 SceneDelegate 创建 UIWindow，兼容当前 SDK 的 UIScene 启动要求。界面包含麦克风授权、开始/停止录音、最近录音播放/停止、时长与音量。录音保存到应用 Documents 目录，每次使用独立文件名。真机麦克风录音与跨端互播仍需设备验证。

从仓库根目录验证模拟器构建：

```sh
xcodebuild -project ios/Example/OggOpusDemo.xcodeproj -scheme OggOpusDemo \
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

维护者修改 `project.yml` 后，可在本目录执行 `xcodegen generate` 重新生成工程，并提交工程文件。

录音使用 AVAudioEngine 获取输入设备的实际 PCM 格式，通过 AVAudioConverter 转为 16 kHz 单声道 Int16。无麦克风、权限未授予、转换失败或音频中断时，Demo 会显示 `OggOpusRecorder.shared.lastError`。模拟器需要宿主 Mac 有可用的输入设备并允许麦克风访问。

`OggOpusTests` 使用生成的音频测试 16/44.1/48 kHz、单/双声道的转换与 Opus 编解码，不采集麦克风。选择已启动模拟器后，在 Xcode 中按 Command-U 运行；硬件录音仍需在实际设备上验证。
