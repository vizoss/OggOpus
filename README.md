# OggOpus SDK

[简体中文](README.zh-CN.md)

**Android demo: [android](android)**. Open this directory in Android Studio and run the `sample` module. See the [Android demo guide](android/README.md).

**Xcode demo: [ios/Example/OggOpusDemo.xcodeproj](ios/Example/OggOpusDemo.xcodeproj)**. Open it directly, select the `OggOpusDemo` scheme, and select your signing team for a physical device. See the [demo guide](ios/Example/README.md).

Cross-platform Ogg Opus codec, microphone recorder, and player for Android and iOS. Both platforms create standards-compliant `.ogg` files with the same defaults: **16 kHz, mono, signed 16-bit PCM, 20 ms Opus frames**.

## Install

### Android

Requires Android API 21+. Add the public GitHub Maven repository to `settings.gradle.kts`:

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

```kotlin
dependencies {
    implementation("io.github.vizoss.oggopus:oggopus:1.0.0")
}
```

Declare `android.permission.RECORD_AUDIO` and request it at runtime before recording.

### iOS — Swift Package Manager

In Xcode choose **File → Add Package Dependencies**, enter `https://github.com/vizoss/OggOpus.git`, select version `1.0.0`, then link the `OggOpus` product. iOS 15+ is required.

### iOS — CocoaPods

```ruby
platform :ios, '15.0'

target 'YourApp' do
  pod 'OggOpus', :git => 'https://github.com/vizoss/OggOpus.git', :tag => '1.0.0'
end
```

Use exactly one iOS distribution method per target. Add `NSMicrophoneUsageDescription` to the app's `Info.plist` and request microphone permission before recording.

## Record and play

### Android

```kotlin
val recorder = OggOpusRecorder(applicationContext)
val player = OggOpusPlayer(applicationContext)
val output = File(filesDir, "voice.ogg").absolutePath

recorder.start(output, maxDurationMs = 60_000) { event ->
    when (event.state) {
        OggOpusState.RECORDING -> meter.progress = (event.levelDb + 60).toInt()
        OggOpusState.FINISHED -> player.play(event.path)
        OggOpusState.ERROR -> showError()
        else -> Unit
    }
}

// Later, including on lifecycle teardown:
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
        meter.progress = Float(max(-60, levelDb) + 60) / 60
    }
}

OggOpusRecorder.shared.stopRecording()
OggOpusPlayer.shared.stopPlaying()
```

Callbacks report approximately every 100–200 ms. Android and iOS recorder callbacks use the main thread. iOS player callbacks may originate on an audio thread; dispatch UI work to the main queue. iOS capture uses the actual microphone format and explicitly resamples to 16 kHz mono; check `OggOpusRecorder.shared.lastError` if starting fails or recording ends unexpectedly.

iOS recording starts, stops, and finalizes asynchronously on a serial background queue. `startRecording` returning `true` means the request was accepted, not that microphone startup has completed. Asynchronous startup failures deliver a `finished == true` callback; inspect `lastError` there. A `false` return means rejection without a callback. `isRecording()` includes startup and finalization.

## PCM codec

Use the codec API for file conversion or when PCM comes from another capture pipeline. The PCM input/output is little-endian 16-bit mono at 16 kHz.

```kotlin
val codec = OggOpusCodec()
check(codec.encodeWav(inputWav.absolutePath, outputOgg.absolutePath))
check(codec.decodeOgg(outputOgg.absolutePath, restoredWav.absolutePath))
```

```swift
let ogg = try OggOpusCodec.encode(pcm: pcmData)
let pcm = try OggOpusCodec.decode(oggOpus: ogg)
```

## Lifecycle and limitations

- Do not start a recorder or player twice. Stop it when a screen or service is destroyed.
- The Android native codec maintains a single native stream; serialize recording, playback, and low-level codec operations.
- The recorder uses the microphone and configures a play-and-record audio session on iOS. Integrate with your app's call/RTC audio-session policy when applicable.
- `.ogg` is the correct extension; it contains an Ogg container with Opus packets, not raw Opus bytes.

## Build and release

Android source and AAR build are in [android](android/); iOS source is in [ios/Sources/OggOpus](ios/Sources/OggOpus/). Release tags must be `x.y.z` and match both `android/gradle.properties` and `OggOpus.podspec`.

Pushing a tag publishes Android artifacts to the repository's immutable `maven-repo` branch. The iOS workflow runs CocoaPods lint; CocoaPods consumers may use the matching tag as shown above. Before the first public release, change `vizoss/OggOpus` URLs if this repository is hosted elsewhere.

The Android native implementation includes libogg and libopus source; their upstream license files remain under `android/oggopus/src/main/cpp/third_part/`. The CocoaPods package vendors the matching Ybrid XCFrameworks and preserves their license files in `ios/Vendor/`.
