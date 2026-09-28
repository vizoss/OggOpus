import XCTest
import AVFoundation
@testable import OggOpus

final class RecordingConversionTests: XCTestCase {
    func testInvalidDurationIsRejectedWithoutStartingAudio() {
        let recorder = OggOpusRecorder.shared
        XCTAssertFalse(recorder.startRecording("unused.opus", 0) { _, _, _, _ in
            XCTFail("A rejected request must not deliver callbacks")
        })
        XCTAssertFalse(recorder.isRecording())
        XCTAssertNotNil(recorder.lastError)
    }

    func testStartupFailureCompletesOnMainAndAllowsRetry() {
        let recorder = OggOpusRecorder.shared
        // A missing parent makes startup fail even if microphone access is granted.
        let path = NSTemporaryDirectory() + UUID().uuidString + "/recording.opus"
        for _ in 0..<2 {
            let completed = expectation(description: "Asynchronous startup failure")
            completed.assertForOverFulfill = true
            DispatchQueue.main.async {
                XCTAssertTrue(recorder.startRecording(path) { _, _, resultPath, finished in
                    guard finished else { return }
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(resultPath, path)
                    XCTAssertFalse(recorder.isRecording())
                    XCTAssertNotNil(recorder.lastError)
                    completed.fulfill()
                })
                // Stop must remain safe while startup is still pending.
                recorder.stopRecording()
            }
            wait(for: [completed], timeout: 15)
        }
    }

    func testHardwareFormatsConvertToMono16k() throws {
        for rate in [16000.0, 44100.0, 48000.0] {
            for channels: AVAudioChannelCount in [1, 2] {
                let input = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                      sampleRate: rate, channels: channels, interleaved: false))
                let converter = try RecordingPCMConverter(input: input)
                var pcm = Data()
                var position = 0
                while position < Int(rate) {
                    let frames = min(1024, Int(rate) - position)
                    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: input, frameCapacity: UInt32(frames)))
                    buffer.frameLength = UInt32(frames)
                    for channel in 0..<Int(channels) {
                        let samples = try XCTUnwrap(buffer.floatChannelData?[channel])
                        for i in 0..<frames { samples[i] = Float(sin(Double(position + i) * 2 * .pi * 440 / rate) * 0.25) }
                    }
                    pcm.append(try converter.convert(buffer))
                    position += frames
                }
                pcm.append(try converter.finish())
                XCTAssertEqual(converter.outputFormat.sampleRate, 16000)
                XCTAssertEqual(converter.outputFormat.channelCount, 1)
                XCTAssertEqual(converter.outputFormat.commonFormat, .pcmFormatInt16)
                XCTAssertEqual(Double(pcm.count / 2), 16000, accuracy: 2, "rate=\(rate), channels=\(channels)")
                XCTAssertTrue(pcm.contains { $0 != 0 }, "Conversion must preserve audio, not produce silence")
                // Exercise the same Opus input contract as the recorder after resampling.
                let ogg = try OggOpusCodec.encode(pcm: pcm)
                XCTAssertTrue(OggOpusCodec.isOggOpus(ogg))
                XCTAssertFalse(try OggOpusCodec.decode(oggOpus: ogg).isEmpty)
            }
        }
    }
}
