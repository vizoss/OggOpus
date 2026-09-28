//
//  OggOpusAudioPlayer.swift
//  THK-IM-IOS
//
//  Created by vizoss on 2023/6/13.
//

import AVFoundation

public class OggOpusAudioPlayer {

    public static let shared = OggOpusAudioPlayer()

    private let LogTag = "OggOpusAudioPlayer"
    private let lock = NSLock()
    private let callbackInterval = 100  // 单位ms
    private var _audioFormat = AudioStreamBasicDescription()

    private var _callback: OggOpusCallback?
    private var _filePath: String?
    private var _audioFile: FileHandle?
    private var _oggDecoder: OGGDecoder?

    // 定义一个 AudioQueueRef 对象
    private var _audioQueue: AudioQueueRef?
    // 定义一个 AudioStreamBasicDescription 对象
    private var buffers = [AudioQueueBufferRef?]()
    private var idleBufferTag = [Bool]()

    private var _startTimestamp: Int64?
    private var _currentLen = 0
    private var lastCallbackTime: Int64 = 0

    private let _bufferCount: UInt32
    private init() {
        _audioFormat.mSampleRate = 16000
        _audioFormat.mFormatID = kAudioFormatLinearPCM
        _audioFormat.mFormatFlags =
            kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
        _audioFormat.mBitsPerChannel = 16
        _audioFormat.mChannelsPerFrame = 1
        _audioFormat.mFramesPerPacket = 1
        _audioFormat.mBytesPerFrame =
            _audioFormat.mChannelsPerFrame * (_audioFormat.mBitsPerChannel / 8)
        _audioFormat.mBytesPerPacket =
            _audioFormat.mBytesPerFrame * _audioFormat.mFramesPerPacket
        _audioFormat.mReserved = 0
        _bufferCount =
            _audioFormat.mBytesPerPacket
            * UInt32((_audioFormat.mSampleRate / 10))
    }

    let audioPlayAQOutputCallback: AudioQueueOutputCallback = {
        (userData, audioQueueRef, audioQueueBufferRef) in
        if userData != nil {
            let player = Unmanaged<OggOpusAudioPlayer>.fromOpaque(userData!)
                .takeUnretainedValue()
            for i in 0..<player.buffers.count {
                if player.buffers[i] == audioQueueBufferRef {
                    player.idleBufferTag[i] = true
                }
            }
            player.playPCMData()
        }
    }

    private func initPlaying() -> Bool {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                AVAudioSession.Category.playAndRecord,
                options: [
                    .defaultToSpeaker,
                    .allowAirPlay,
                    .allowBluetoothA2DP,
                ]
            )
            try AVAudioSession.sharedInstance().setActive(true)

            let format = AVAudioFormat(streamDescription: &_audioFormat)
            if format == nil {
                DDLogError("[\(LogTag)] format error")
                return false
            }

            let status = AudioQueueNewOutput(
                &_audioFormat,
                audioPlayAQOutputCallback,
                UnsafeMutableRawPointer(
                    Unmanaged.passUnretained(self).toOpaque()
                ),
                nil,
                nil,
                0,
                &_audioQueue
            )
            if _audioQueue == nil || status != noErr {
                return false
            }

            // 设置音量
            AudioQueueSetParameter(_audioQueue!, kAudioQueueParam_Volume, 1.0)

        } catch {
            DDLogError("\(error)")
            return false
        }
        return true
    }

    private func releasePlaying() {
        lock.lock()
        defer { lock.unlock() }
        do {
            try self._audioFile?.close()
        } catch {
            DDLogError("\(error)")
        }
        if let queue = self._audioQueue {
            let status = AudioQueueStop(queue, false)
            if status == noErr {
                _ = AudioQueueDispose(queue, false)
            }
        }
        _currentLen = 0
        _oggDecoder = nil
        _audioQueue = nil
        _audioFile = nil
        _oggDecoder = nil
        _filePath = nil
        _startTimestamp = nil
        buffers.removeAll()
        idleBufferTag.removeAll()
        _callback = nil
    }

    private func decodeAndPlay() -> Bool {
        do {
            if self._filePath == nil {
                return false
            }
            _audioFile = FileHandle(forReadingAtPath: self._filePath!)
            if _audioFile == nil {
                DDLogError("[\(LogTag)] _audioFile read error")
                return false
            }
            if self._audioFile == nil {
                return false
            }
            let audioData = self._audioFile!.readDataToEndOfFile()

            self._oggDecoder = try OGGDecoder(audioData: audioData)
            if self._oggDecoder == nil {
                DDLogError("[\(LogTag)] ops decoder error")
                return false
            }

            if _audioQueue == nil {
                return false
            }

            var status = noErr
            // 初始化需要的缓冲区
            for _ in 0..<2 {
                var bufferRef: AudioQueueBufferRef? = nil
                status = AudioQueueAllocateBuffer(
                    _audioQueue!,
                    _bufferCount,
                    &bufferRef
                )
                buffers.append(bufferRef)
                if status != noErr {
                    return false
                }
                idleBufferTag.append(true)
            }
            status = AudioQueueStart(_audioQueue!, nil)
            if status != noErr {
                DDLogError("[\(LogTag)] Error starting audio queue: \(status)")
                return false
            }
        } catch {
            DDLogError("[\(LogTag)] \(error)")
            return false
        }
        return true
    }

    public func isPlaying() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _audioQueue != nil {
            return true
        }
        return false
    }

    public func currentPlayPath() -> String? {
        if !isPlaying() {
            return nil
        }
        return _filePath
    }

    public func startPlaying(
        _ filePath: String,
        _ callback: @escaping OggOpusCallback
    ) -> Bool {
        if self.isPlaying() {
            return false
        }
        if !initPlaying() {
            releasePlaying()
            return false
        } else {
            self._filePath = filePath
            self._callback = callback
            DispatchQueue.global().async { [weak self] in
                guard let sf = self else { return }
                let ret = sf.decodeAndPlay()
                if !ret {
                    sf.stopPlaying()
                } else {
                    sf.playPCMData()
                }
            }
            return true
        }
    }

    private func playPCMData() {
        guard let oggDecoder = self._oggDecoder else {
            return
        }
        if _currentLen >= oggDecoder.pcmData.count {
            stopPlaying()
            return
        }
        lock.lock()
        let length: Int = Int(_bufferCount)
        var end = _currentLen + length
        if end > oggDecoder.pcmData.count {
            end = oggDecoder.pcmData.count
        }
        let data = oggDecoder.pcmData.subdata(in: _currentLen..<end)
        doCallback(data)
        for i in 0..<self.idleBufferTag.count {
            if self.idleBufferTag[i] {
                let buffer = self.buffers[i]
                if buffer != nil {
                    // 将 AVAudioPCMBuffer 中的音频数据复制到 AudioQueueBufferRef 中
                    memcpy(
                        buffer!.pointee.mAudioData,
                        (data as NSData).bytes,
                        (end - _currentLen)
                    )
                    buffer!.pointee.mAudioDataByteSize = UInt32(end - _currentLen)
                    AudioQueueEnqueueBuffer(_audioQueue!, buffer!, 0, nil)
                }
                self.idleBufferTag[i] = false
            }
        }
        _currentLen = end
        lock.unlock()
    }

    public func stopPlaying() {
        if _startTimestamp == nil {
            _startTimestamp = Date().oggOpusMilliseconds
        }
        if _callback != nil {
            let now = Date().oggOpusMilliseconds
            let path = self._filePath ?? ""
            self._filePath = nil
            self._callback?(0, Int(now - self._startTimestamp!), path, true)
            lastCallbackTime = now
        }
        releasePlaying()
    }

    private func doCallback(_ audioPCMData: Data) {
        guard let cb = self._callback else { return }
        guard let path = self._filePath else { return }
        let now = Date().oggOpusMilliseconds
        if self._startTimestamp == nil {
            self._startTimestamp = now
        }
        if (now - lastCallbackTime) > callbackInterval {
            // 计算分贝并回调
            let db = OggOpusAudioLevel.decibels(audioPCMData)
            cb(db, Int(now - self._startTimestamp!), path, false)
            lastCallbackTime = now
        }
    }
}
