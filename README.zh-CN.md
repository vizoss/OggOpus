# OggOpus SDK

[English](README.md)

**Android Demo 入口：[android](android)**。用 Android Studio 打开此目录，选择 `sample` 模块运行，详见 [Android Demo 说明](android/README.md)。

**Xcode Demo 入口：[ios/Example/OggOpusDemo.xcodeproj](ios/Example/OggOpusDemo.xcodeproj)**。直接打开，选择 `OggOpusDemo` scheme 即可运行；真机需选择自己的签名 Team。详见 [Demo 说明](ios/Example/README.md)。

面向 Android 与 iOS 的 Ogg Opus 音频 SDK，提供 PCM/Ogg Opus 编解码、麦克风录制与播放。两端统一采用 **16 kHz、单声道、16-bit PCM、20 ms Opus 帧**，生成标准 `.ogg` 文件，可以跨端互录互播。

## 接入

### Android：GitHub Maven

最低 Android API 21。在项目 `settings.gradle.kts` 中添加：

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven(url = "https://raw.githubusercontent.com/vizoss/OggOpus/maven-repo/") {
            content { includeGroup("io.github.vizoss.oggopus") }
        }
    }
}
```

在 app 模块添加：

```kotlin
dependencies {
    implementation("io.github.vizoss.oggopus:oggopus:1.0.0")
}
```

在 Manifest 中声明 `android.permission.RECORD_AUDIO`，并在调用录制前完成运行时授权。

### iOS：SPM

最低 iOS 15。Xcode 选择 **File → Add Package Dependencies**，输入 `https://github.com/vizoss/OggOpus.git`，选择 `1.0.0`，将 `OggOpus` product 添加到业务 target。

### iOS：CocoaPods

```ruby
platform :ios, '15.0'

target 'YourApp' do
  pod 'OggOpus', :git => 'https://github.com/vizoss/OggOpus.git', :tag => '1.0.0'
end
```

同一 target 只能选择 SPM 或 CocoaPods 其中一种。`Info.plist` 需要配置 `NSMicrophoneUsageDescription`，业务侧需要自行请求麦克风权限。

## 录制与播放

### Android

```kotlin
val recorder = OggOpusRecorder(applicationContext)
val player = OggOpusPlayer(applicationContext)
val path = File(filesDir, "voice.ogg").absolutePath

recorder.start(path, maxDurationMs = 60_000) { event ->
    when (event.state) {
        OggOpusState.RECORDING -> updateVolume(event.levelDb)
        OggOpusState.FINISHED -> player.play(event.path)
        OggOpusState.ERROR -> showRecordError()
        else -> Unit
    }
}

// 页面销毁、切换语音或用户主动取消时调用
recorder.stop()
player.stop()
```

### iOS

```swift
let path = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("voice.ogg").path

OggOpusRecorder.shared.startRecording(path, 60) { levelDb, elapsedMs, path, finished in
    if finished {
        _ = OggOpusPlayer.shared.startPlaying(path) { _, _, _, _ in }
    } else {
        DispatchQueue.main.async { updateVolume(levelDb) }
    }
}

OggOpusRecorder.shared.stopRecording()
OggOpusPlayer.shared.stopPlaying()
```

Android 和 iOS 录音回调在主线程；iOS 播放回调可能来自音频线程，更新界面时请切回主线程。iOS 按麦克风实际格式采集，再转换为 16 kHz 单声道；启动失败或意外结束时，可读取 `OggOpusRecorder.shared.lastError` 查看原因。

iOS 录音启动、停止和收尾均在后台串行队列执行，不同步等待主线程。`startRecording` 返回 `true` 表示已接受启动请求，并不表示麦克风已启动；异步启动失败会触发 `finished == true` 回调，此时读取 `lastError`。返回 `false` 表示请求被拒绝，不产生回调。`isRecording()` 包含启动和收尾中的状态。

## 编解码

PCM 输入与输出均为小端、16-bit、单声道、16 kHz。

```kotlin
val codec = OggOpusCodec()
codec.encodeWav(inputWav.absolutePath, outputOgg.absolutePath)
codec.decodeOgg(outputOgg.absolutePath, outputWav.absolutePath)
```

```swift
let oggData = try OggOpusCodec.encode(pcm: pcmData)
let pcmData = try OggOpusCodec.decode(oggOpus: oggData)
```

## 使用约束

- 录音、播放与原生编解码共享 Android 的单个 native stream，必须串行使用。
- iOS 录音和播放会配置 `playAndRecord` 音频会话；与通话/WebRTC 同时使用时，应由业务统一管理音频会话。
- 输出扩展名使用 `.ogg`。这是包含 Opus packets 的 Ogg 容器，不是裸 Opus 数据。
- 示例位于 [examples/android](examples/android) 和 [examples/ios](examples/ios)。

## 构建与发布

Android 模块在 [android](android)，iOS 源码在 [ios/Sources/OggOpus](ios/Sources/OggOpus)。发布 tag 必须是 `x.y.z`，且与 `android/gradle.properties`、`OggOpus.podspec` 中的版本完全一致。

推送 tag 后，Android 自动发布至 GitHub `maven-repo` 分支（历史版本不可覆盖）；iOS 自动执行 pod lint。首次公开发布前，如果仓库不在 `vizoss/OggOpus`，请替换文档、Podspec 和 SPM 中的仓库地址。

Android 内含 libogg、libopus 的源码及其上游许可证，位于 `android/oggopus/src/main/cpp/third_part/`；CocoaPods 包内置匹配的 Ybrid XCFramework，并在 `ios/Vendor/` 保留其许可证。
