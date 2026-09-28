package com.thk.oggopus

import android.test.InstrumentationTestCase
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.math.sin

/** On-device JNI tests: deterministic PCM, no microphone permission or user recordings required. */
@Suppress("DEPRECATION")
class AudioRegressionTest : InstrumentationTestCase() {
    fun testChunkingDurationAndRepeatedDecode() {
        val native = OggOpusNative()
        for (samples in listOf(1, 100, 319, 320, 321, 600, 16000, 17321)) {
            val file = File(instrumentation.targetContext.cacheDir, "regression-$samples.ogg")
            try {
                assertEquals(1, native.startRecording(file.path))
                var offset = 0
                var chunk = 0
                val chunks = intArrayOf(37, 4096, 151, 960, 13)
                while (offset < samples) {
                    val count = minOf(chunks[chunk++ % chunks.size], samples - offset)
                    val pcm = ByteBuffer.allocateDirect(count * 2).order(ByteOrder.LITTLE_ENDIAN)
                    repeat(count) { pcm.putShort((sin((offset + it) * 2 * Math.PI * 440 / 16000) * 8000).toInt().toShort()) }
                    assertEquals(1, native.writeFrame(pcm, count * 2))
                    offset += count
                }
                native.stopRecording()
                assertEquals(1, native.isOpusFile(file.path))
                repeat(2) {
                    assertEquals(1, native.openOpusFile(file.path))
                    assertEquals(0, native.getFinished())
                    assertEquals(samples * 3L, native.getTotalPcmDuration())
                    val output = ByteBuffer.allocateDirect(4096)
                    var frames = 0L
                    var reads = 0
                    while (native.getFinished() == 0) {
                        native.readOpusFile(output, output.capacity())
                        assertTrue(native.getSize() >= 0)
                        frames += native.getSize() / 4
                        assertTrue("Decode must terminate", ++reads < 1000)
                    }
                    assertEquals("Decoded duration must match all input samples", samples * 3L, frames)
                    native.closeOpusFile()
                }
            } finally { native.stopRecording(); native.closeOpusFile(); file.delete() }
        }
    }

    fun testRepeatedPlaybackDrainsTailAndReleasesSession() {
        val file = File(instrumentation.targetContext.cacheDir, "playback-regression.ogg")
        val native = OggOpusNative()
        val player = OggOpusPlayer(instrumentation.targetContext)
        try {
            assertEquals(1, native.startRecording(file.path))
            // One second of silence tests AudioTrack timing without playing a test tone.
            assertEquals(1, native.writeFrame(ByteBuffer.allocateDirect(32000), 32000))
            native.stopRecording()
            repeat(2) {
                val done = CountDownLatch(1)
                var terminal: OggOpusProgress? = null
                val start = android.os.SystemClock.elapsedRealtime()
                assertTrue(player.play(file.path) { event ->
                    if (event.state == OggOpusState.FINISHED || event.state == OggOpusState.ERROR) {
                        terminal = event
                        done.countDown()
                    }
                })
                assertTrue(done.await(10, TimeUnit.SECONDS))
                assertEquals(OggOpusState.FINISHED, terminal?.state)
                assertFalse(player.isPlaying())
                assertTrue("Tail must be consumed before completion", android.os.SystemClock.elapsedRealtime() - start >= 900)
            }
        } finally { player.stop(); file.delete() }
    }
}
