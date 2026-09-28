import OggOpus

func recordVoiceMessage() {
    let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("voice.ogg").path
    OggOpusRecorder.shared.startRecording(path, 60) { _, _, path, finished in
        guard finished else { return }
        _ = OggOpusPlayer.shared.startPlaying(path) { _, _, _, _ in }
    }
}

