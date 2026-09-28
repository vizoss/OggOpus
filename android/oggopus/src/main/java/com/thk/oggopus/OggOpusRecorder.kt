package com.thk.oggopus

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

/** Records microphone PCM as a standard `.ogg` / Opus file. One recorder/player session may run at a time. */
class OggOpusRecorder(private val context: Context) {
    companion object {
        const val SAMPLE_RATE = 16_000
        private const val FRAME_BYTES = 640 // 20 ms, mono, signed 16-bit
    }

    private val native = OggOpusNative()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val recording = AtomicBoolean(false)
    private val active = AtomicBoolean(false)
    @Volatile private var activePath: String? = null

    fun isRecording(): Boolean = active.get()

    /**
     * Starts recording. The caller must have granted RECORD_AUDIO. `maxDurationMs` must be positive.
     * Returns false without starting when the SDK is busy, permission is absent, or initialization fails.
     */
    fun start(path: String, maxDurationMs: Long = 60_000, callback: OggOpusCallback? = null): Boolean {
        if (maxDurationMs <= 0 || active.get() ||
            context.checkCallingOrSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) return false
        val minimum = AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (minimum <= 0) return false
        val bufferSize = ((minimum + FRAME_BYTES - 1) / FRAME_BYTES) * FRAME_BYTES
        val recorder = try {
            AudioRecord(MediaRecorder.AudioSource.MIC, SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, bufferSize)
        } catch (_: IllegalArgumentException) { return false }
        if (!active.compareAndSet(false, true)) { recorder.release(); return false }
        if (!NativeSession.acquire()) { active.set(false); recorder.release(); return false }
        recording.set(true)
        activePath = path
        Thread {
            val startedAt = System.currentTimeMillis()
            var state = OggOpusState.FINISHED
            try {
                check(recorder.state == AudioRecord.STATE_INITIALIZED)
                recorder.startRecording()
                if (native.startRecording(path) != 1) throw IllegalStateException("Cannot initialize Ogg Opus encoder")
                val direct = ByteBuffer.allocateDirect(bufferSize)
                var lastCallbackAt = 0L
                while (recording.get() && System.currentTimeMillis() - startedAt < maxDurationMs) {
                    direct.clear()
                    val count = recorder.read(direct, bufferSize)
                    check(count > 0) { "AudioRecord.read failed: $count" }
                    check(native.writeFrame(direct, count) == 1) { "Opus encoding failed" }
                    val now = System.currentTimeMillis()
                    if (now - lastCallbackAt >= 100) {
                        val copy = ByteArray(minOf(count, 256))
                        direct.rewind(); direct.get(copy)
                        dispatch(callback, OggOpusProgress(path, now - startedAt, pcmDecibels(copy), OggOpusState.RECORDING))
                        lastCallbackAt = now
                    }
                }
            } catch (error: Exception) {
                android.util.Log.e("OggOpusRecorder", "Recording failed", error)
                state = OggOpusState.ERROR
            } finally {
                recording.set(false)
                activePath = null
                native.stopRecording()
                try { recorder.stop() } catch (_: Throwable) { }
                recorder.release()
                active.set(false)
                NativeSession.release()
                dispatch(callback, OggOpusProgress(path, System.currentTimeMillis() - startedAt, 0.0, state))
            }
        }.start()
        return true
    }

    fun stop() { recording.set(false) }

    private fun dispatch(callback: OggOpusCallback?, progress: OggOpusProgress) {
        callback ?: return
        mainHandler.post { callback.onProgress(progress) }
    }
}
