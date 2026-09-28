package com.thk.oggopus

import java.nio.ByteBuffer

/** Internal JNI bridge. Public callers should use [OggOpusCodec], [OggOpusRecorder], or [OggOpusPlayer]. */
internal class OggOpusNative {
    init { System.loadLibrary("ogg_opus") }

    external fun encode(wavFile: String, oggFile: String, options: String = ""): Int
    external fun decode(oggFile: String, wavFile: String, options: String = ""): Int
    external fun startRecording(oggFile: String): Int
    external fun stopRecording()
    external fun writeFrame(frame: ByteBuffer, length: Int): Int
    external fun isOpusFile(path: String): Int
    external fun openOpusFile(path: String): Int
    external fun seekOpusFile(position: Float): Int
    external fun closeOpusFile()
    external fun readOpusFile(buffer: ByteBuffer, capacity: Int)
    external fun getFinished(): Int
    external fun getSize(): Int
    external fun getPcmOffset(): Long
    external fun getTotalPcmDuration(): Long
}

