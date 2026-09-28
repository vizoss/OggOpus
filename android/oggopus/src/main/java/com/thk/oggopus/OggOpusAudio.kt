package com.thk.oggopus

/** State reported by recorder and player callbacks. Callbacks are dispatched on the main thread. */
enum class OggOpusState { RECORDING, PLAYING, FINISHED, ERROR }

data class OggOpusProgress(
    val path: String,
    val elapsedMs: Long,
    val levelDb: Double,
    val state: OggOpusState,
)

fun interface OggOpusCallback { fun onProgress(progress: OggOpusProgress) }

internal fun pcmDecibels(bytes: ByteArray): Double {
    if (bytes.size < 2) return -120.0
    var sum = 0.0
    var index = 0
    while (index + 1 < bytes.size) {
        val sample = ((bytes[index + 1].toInt() shl 8) or (bytes[index].toInt() and 0xff)).toShort().toInt()
        sum += sample.toDouble() * sample
        index += 2
    }
    val rms = kotlin.math.sqrt(sum / (index / 2))
    return if (rms == 0.0) -120.0 else 20.0 * kotlin.math.log10(rms / Short.MAX_VALUE)
}

