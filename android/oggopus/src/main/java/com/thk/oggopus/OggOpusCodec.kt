package com.thk.oggopus

/** Offline Ogg Opus <-> WAV conversion. All paths are app-private absolute paths. */
class OggOpusCodec {
    private val native = OggOpusNative()

    fun encodeWav(wavPath: String, oggPath: String, options: String = ""): Boolean =
        native.encode(wavPath, oggPath, options) != 0

    fun decodeOgg(oggPath: String, wavPath: String, options: String = ""): Boolean =
        native.decode(oggPath, wavPath, options) != 0

    fun isOggOpus(path: String): Boolean = native.isOpusFile(path) > 0
}

