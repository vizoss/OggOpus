import Foundation

/** Receives audio level and lifecycle updates. Recorder callbacks use main; player callbacks may use an audio thread. */
public typealias OggOpusCallback = (_ levelDb: Double, _ elapsedMs: Int, _ path: String, _ finished: Bool) -> Void

internal func DDLogError(_ value: Any) { }
internal func DDLogInfo(_ value: Any) { }

internal extension Date {
    var oggOpusMilliseconds: Int64 { Int64((timeIntervalSince1970 * 1_000).rounded()) }
}

internal enum OggOpusAudioLevel {
    static func decibels(_ data: Data) -> Double {
        guard data.count >= 2 else { return -120 }
        var sum = 0.0
        data.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            for sample in samples { sum += Double(sample) * Double(sample) }
            guard !samples.isEmpty else { return }
            sum = sqrt(sum / Double(samples.count))
        }
        return sum == 0 ? -120 : 20 * log10(sum / Double(Int16.max))
    }
}
