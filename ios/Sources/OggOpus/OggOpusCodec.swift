import AudioToolbox
import Foundation

/** Stateless helpers for standard 16 kHz, mono, signed 16-bit PCM and Ogg Opus data. */
public enum OggOpusCodec {
    public static let sampleRate = 16_000
    public static let channels = 1

    /** Encodes raw little-endian PCM to a complete standard Ogg Opus stream. */
    public static func encode(pcm: Data) throws -> Data {
        var format = AudioStreamBasicDescription()
        format.mSampleRate = Float64(sampleRate)
        format.mFormatID = kAudioFormatLinearPCM
        format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
        format.mBitsPerChannel = 16
        format.mChannelsPerFrame = UInt32(channels)
        format.mFramesPerPacket = 1
        format.mBytesPerFrame = 2
        format.mBytesPerPacket = 2
        let encoder = try OGGEncoder(format: format, opusRate: Int32(sampleRate), application: .audio)
        try encoder.encode(pcm: pcm)
        return try encoder.endstream()
    }

    /** Decodes a standard Ogg Opus stream to raw little-endian signed 16-bit PCM. */
    public static func decode(oggOpus: Data) throws -> Data {
        try OGGDecoder(audioData: oggOpus).pcmData
    }

    public static func isOggOpus(_ data: Data) -> Bool {
        data.range(of: Data("OpusHead".utf8)) != nil
    }
}

public typealias OggOpusRecorder = OggOpusAudioRecorder
public typealias OggOpusPlayer = OggOpusAudioPlayer

