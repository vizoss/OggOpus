import AVFoundation

/// Captures the hardware format, then explicitly resamples to 16 kHz mono Int16.
public final class OggOpusAudioRecorder {
    public static let shared = OggOpusAudioRecorder()
    private let queue = DispatchQueue(label: "com.thk.oggopus.recording")
    private let stateLock = NSLock()
    private var recording = false
    private var engine: AVAudioEngine?
    private var converter: RecordingPCMConverter?
    private var encoder: OGGEncoder?
    private var output: FileHandle?
    private var callback: OggOpusCallback?
    private var path = ""
    private var generation: UUID?
    private var samples = 0
    private var limit = 0
    private var lastNotify = 0
    private var storedFailure: String?
    private var failure: String? {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return storedFailure
        }
        set {
            stateLock.lock()
            storedFailure = newValue
            stateLock.unlock()
        }
    }
    private var observers: [NSObjectProtocol] = []
    private init() {}

    public var lastError: String? { failure }
    public func isRecording() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return recording
    }

    /// Returns whether the request was accepted, including asynchronous startup.
    /// Startup failures deliver a finished callback on main; inspect lastError there.
    public func startRecording(_ filePath: String, _ maxDuration: Int = 60,
                               _ callback: @escaping OggOpusCallback) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !recording else { return false }
        storedFailure = nil
        guard maxDuration > 0, maxDuration <= Int.max / 32000 else {
            storedFailure = "Recording duration must be positive."
            return false
        }
        recording = true
        // Enqueue while holding the short state lock so a concurrent stop cannot
        // overtake this start. Never hold this lock during audio or file work.
        queue.async { [self] in
            dispatchPrecondition(condition: .notOnQueue(.main))
            self.callback = callback
            self.path = filePath
            self.samples = 0
            self.generation = UUID()
            let session = AVAudioSession.sharedInstance()
            guard session.recordPermission == .granted else {
                failure = "Microphone permission has not been granted."
                cleanup()
                DispatchQueue.main.async { callback(0, 0, filePath, true) }
                return
            }
            do {
                try session.setCategory(.playAndRecord, mode: .default,
                                        options: [.defaultToSpeaker, .allowBluetooth])
                try session.setActive(true)
                guard session.isInputAvailable else { throw CaptureError.invalidInput }
                let engine = AVAudioEngine()
                let input = engine.inputNode
                let format = input.outputFormat(forBus: 0)
                let converter = try RecordingPCMConverter(input: format)
                let encoder = try OGGEncoder(format: converter.outputFormat.streamDescription.pointee,
                                             opusRate: 16000, application: .audio)
                guard FileManager.default.createFile(atPath: filePath, contents: nil) else {
                    throw CaptureError.fileCreation
                }
                let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: filePath))
                let token = UUID()
                self.engine = engine
                self.converter = converter
                self.encoder = encoder
                self.output = handle
                self.callback = callback
                self.path = filePath
                self.samples = 0
                self.lastNotify = 0
                self.limit = maxDuration * 16000
                self.generation = token

                input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                    // The engine reuses tap memory; copy it before dispatching.
                    guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return }
                    copy.frameLength = buffer.frameLength
                    let source = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
                    let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
                    for i in 0..<source.count {
                        if let src = source[i].mData, let dst = destination[i].mData {
                            memcpy(dst, src, Int(source[i].mDataByteSize))
                        }
                    }
                    self?.queue.async { [weak self] in self?.consume(copy, token: token) }
                }
                engine.prepare()
                try engine.start()
                observeChanges(engine: engine, token: token)
            } catch {
                failure = error.localizedDescription
                cleanup()
                DispatchQueue.main.async { callback(0, 0, filePath, true) }
            }
        }
        return true
    }

    /// Finalizes independently of the next microphone callback; completion is on main.
    public func stopRecording() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard recording else { return }
        queue.async { [weak self] in self?.finish() }
    }

    private func consume(_ buffer: AVAudioPCMBuffer, token: UUID) {
        guard generation == token else { return }
        do {
            if let converter = converter { try append(converter.convert(buffer)) }
            if samples >= limit { finish() }
        } catch { finish(error: error) }
    }

    private func append(_ data: Data) throws {
        let count = min(data.count, max(0, limit - samples) * 2)
        guard count > 0 else { return }
        let pcm = Data(data.prefix(count))
        try encoder?.encode(pcm: pcm)
        if let bytes = encoder?.bitstream() { try output?.write(contentsOf: bytes) }
        samples += count / 2
        let elapsed = samples / 16
        if elapsed - lastNotify >= 200 {
            lastNotify = elapsed
            let cb = callback, filePath = path
            let level = OggOpusAudioLevel.decibels(pcm)
            DispatchQueue.main.async { cb?(level, elapsed, filePath, false) }
        }
    }

    private func finish(error: Error? = nil) {
        dispatchPrecondition(condition: .onQueue(queue))
        dispatchPrecondition(condition: .notOnQueue(.main))
        guard generation != nil else { return }
        if let error = error { failure = error.localizedDescription }
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        do {
            if error == nil, let converter = converter { try append(converter.finish()) }
            if let bytes = try encoder?.endstream() { try output?.write(contentsOf: bytes) }
            try output?.close()
        } catch { failure = error.localizedDescription }
        let completion = callback, savedPath = path, elapsed = samples / 16
        cleanup()
        DispatchQueue.main.async { completion?(0, elapsed, savedPath, true) }
    }

    private func cleanup() {
        dispatchPrecondition(condition: .notOnQueue(.main))
        generation = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        try? output?.close()
        output = nil
        encoder = nil
        converter = nil
        callback = nil
        stateLock.lock()
        recording = false
        stateLock.unlock()
    }

    private func observeChanges(engine: AVAudioEngine, token: UUID) {
        for (name, object) in [
            (AVAudioSession.interruptionNotification, nil as AnyObject?),
            (Notification.Name.AVAudioEngineConfigurationChange, engine as AnyObject?),
            (AVAudioSession.mediaServicesWereResetNotification, nil as AnyObject?)
        ] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: nil) { [weak self] _ in
                self?.queue.async { [weak self] in
                    guard let self = self, self.generation == token else { return }
                    self.finish(error: CaptureError.inputChanged)
                }
            })
        }
    }
}

private enum CaptureError: LocalizedError {
    case invalidInput, fileCreation, conversion, inputChanged
    var errorDescription: String? {
        switch self {
        case .invalidInput: return "Microphone has no valid input format. Check the selected input device and microphone access."
        case .fileCreation: return "Cannot create the recording file."
        case .conversion: return "Cannot convert microphone audio to 16 kHz mono PCM."
        case .inputChanged: return "Recording stopped because the audio input changed or was interrupted."
        }
    }
}

/// Hardware-independent conversion for regression testing.
internal final class RecordingPCMConverter {
    let outputFormat: AVAudioFormat
    private let converter: AVAudioConverter

    init(input: AVAudioFormat) throws {
        guard input.channelCount > 0, input.sampleRate > 0,
              input.streamDescription.pointee.mFormatID == kAudioFormatLinearPCM,
              let output = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000,
                                         channels: 1, interleaved: true),
              let converter = AVAudioConverter(from: input, to: output) else {
            throw CaptureError.invalidInput
        }
        outputFormat = output
        self.converter = converter
    }

    func convert(_ input: AVAudioPCMBuffer) throws -> Data { try drain(input: input, end: false) }
    func finish() throws -> Data { try drain(input: nil, end: true) }

    private func drain(input: AVAudioPCMBuffer?, end: Bool) throws -> Data {
        var provided = false
        var data = Data()
        while true {
            guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 4096) else {
                throw CaptureError.conversion
            }
            var error: NSError?
            let status = converter.convert(to: output, error: &error) { _, inputStatus in
                if !provided, let input = input {
                    provided = true
                    inputStatus.pointee = .haveData
                    return input
                }
                inputStatus.pointee = end ? .endOfStream : .noDataNow
                return nil
            }
            if let error = error { throw error }
            guard status != .error else { throw CaptureError.conversion }
            if output.frameLength > 0, let pcm = output.int16ChannelData?[0] {
                data.append(UnsafeBufferPointer(start: UnsafeRawPointer(pcm).assumingMemoryBound(to: UInt8.self),
                                               count: Int(output.frameLength) * 2))
            }
            if status == .inputRanDry || status == .endOfStream { return data }
            guard output.frameLength > 0 else { throw CaptureError.conversion }
        }
    }
}
