package com.thk.oggopus

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

/** Plays a standard Ogg Opus file through Android's media output. */
class OggOpusPlayer(@Suppress("UNUSED_PARAMETER") context: Context) {
    private val native = OggOpusNative()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val playing = AtomicBoolean(false)
    private val active = AtomicBoolean(false)
    @Volatile private var activePath: String? = null

    fun isPlaying(): Boolean = active.get()
    fun currentPath(): String? = activePath

    fun play(path: String, callback: OggOpusCallback? = null): Boolean {
        if (active.get() || !File(path).isFile) return false
        val minBuffer = AudioTrack.getMinBufferSize(48_000, AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_16BIT)
        if (minBuffer <= 0) return false
        val track = AudioTrack(
            AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build(),
            AudioFormat.Builder().setSampleRate(48_000).setChannelMask(AudioFormat.CHANNEL_OUT_STEREO).setEncoding(AudioFormat.ENCODING_PCM_16BIT).build(),
            minBuffer, AudioTrack.MODE_STREAM, AudioManager.AUDIO_SESSION_ID_GENERATE)
        if (!active.compareAndSet(false, true)) { track.release(); return false }
        if (!NativeSession.acquire()) { active.set(false); track.release(); return false }
        playing.set(true)
        activePath = path
        Thread {
            val startedAt = System.currentTimeMillis()
            var state = OggOpusState.FINISHED
            var framesWritten = 0L
            try {
                check(track.state == AudioTrack.STATE_INITIALIZED)
                if (native.openOpusFile(path) <= 0) throw IllegalArgumentException("Invalid Ogg Opus file")
                track.play()
                val direct = ByteBuffer.allocateDirect(minBuffer)
                var lastCallbackAt = 0L
                while (playing.get() && native.getFinished() == 0) {
                    direct.clear(); native.readOpusFile(direct, minBuffer)
                    val size = native.getSize()
                    check(size >= 0) { "Opus decoding failed" }
                    if (size == 0) break
                    val data = ByteArray(size)
                    direct.rewind(); direct.get(data)
                    var offset = 0
                    while (playing.get() && offset < size) {
                        val written = track.write(data, offset, size - offset)
                        check(written > 0) { "AudioTrack.write failed: $written" }
                        offset += written
                        framesWritten += written / 4
                    }
                    val now = System.currentTimeMillis()
                    if (now - lastCallbackAt >= 100) {
                        dispatch(callback, OggOpusProgress(path, now - startedAt, pcmDecibels(data.copyOf(minOf(size, 256))), OggOpusState.PLAYING))
                        lastCallbackAt = now
                    }
                }
                // Writes enqueue audio; do not release the device until the last frame is played.
                var lastPosition = -1L
                var lastAdvance = android.os.SystemClock.elapsedRealtime()
                while (playing.get()) {
                    val position = track.playbackHeadPosition.toLong() and 0xffffffffL
                    if (position >= framesWritten) break
                    if (position != lastPosition) { lastPosition = position; lastAdvance = android.os.SystemClock.elapsedRealtime() }
                    check(android.os.SystemClock.elapsedRealtime() - lastAdvance < 5000) { "Audio output stalled" }
                    Thread.sleep(10)
                }
            } catch (error: Exception) {
                android.util.Log.e("OggOpusPlayer", "Playback failed", error)
                state = OggOpusState.ERROR
            } finally {
                playing.set(false); activePath = null
                try { native.closeOpusFile() } catch (_: Throwable) { }
                try { track.stop() } catch (_: Throwable) { }
                track.release()
                active.set(false)
                NativeSession.release()
                dispatch(callback, OggOpusProgress(path, System.currentTimeMillis() - startedAt, 0.0, state))
            }
        }.start()
        return true
    }

    fun stop() { playing.set(false) }
    private fun dispatch(callback: OggOpusCallback?, progress: OggOpusProgress) { callback?.let { mainHandler.post { it.onProgress(progress) } } }
}
