package com.thk.oggopus.demo

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import com.thk.oggopus.*
import java.io.File
import java.util.UUID

class MainActivity : Activity() {
    private lateinit var recorder: OggOpusRecorder
    private lateinit var player: OggOpusPlayer
    private lateinit var status: TextView
    private lateinit var recordButton: Button
    private lateinit var playButton: Button
    private lateinit var stopButton: Button
    private var recording = false
    private var playing = false
    private var latest: File? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        recorder = OggOpusRecorder(applicationContext)
        player = OggOpusPlayer(applicationContext)
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val padding = (24 * resources.displayMetrics.density).toInt()
            setPadding(padding, padding, padding, padding)
        }
        layout.addView(TextView(this).apply { text = "OggOpus Demo"; textSize = 26f })
        status = TextView(this).apply { text = "录音完成后，可以播放最近一次录音。"; textSize = 16f }
        layout.addView(status)
        recordButton = Button(this).apply {
            text = "开始录音（最长 60 秒）"
            setOnClickListener {
                if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                    record()
                } else requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 1)
            }
        }
        playButton = Button(this).apply { text = "播放最近录音"; setOnClickListener { play() } }
        stopButton = Button(this).apply { text = "停止"; setOnClickListener { stop() } }
        layout.addView(recordButton)
        layout.addView(stopButton)
        layout.addView(playButton)
        setContentView(layout)
        updateButtons()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1 && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) record()
        else status.text = "请在系统设置中允许麦克风权限。"
    }

    private fun record() {
        if (recording || playing) return
        val output = File(filesDir, "voice-${UUID.randomUUID()}.ogg")
        recording = true
        updateButtons()
        status.text = "正在启动录音…"
        if (!recorder.start(output.absolutePath, 60_000) { event ->
            when (event.state) {
                OggOpusState.RECORDING -> status.text = "录音 ${event.elapsedMs / 1000.0} 秒 · %.1f dB".format(event.levelDb)
                OggOpusState.FINISHED -> {
                    latest = output
                    recording = false
                    status.text = "已保存：${output.absolutePath}"
                }
                OggOpusState.ERROR -> { recording = false; status.text = "录音失败，请检查音频设备。" }
                else -> Unit
            }
            updateButtons()
        }) {
            recording = false
            status.text = "无法启动录音。"
            updateButtons()
        }
    }

    private fun play() {
        if (recording || playing) return
        val input = latest ?: return
        playing = true
        updateButtons()
        if (!player.play(input.absolutePath) { event ->
            when (event.state) {
                OggOpusState.PLAYING -> status.text = "播放 ${event.elapsedMs / 1000.0} 秒"
                OggOpusState.FINISHED -> { playing = false; status.text = "播放结束。" }
                OggOpusState.ERROR -> { playing = false; status.text = "播放失败。" }
                else -> Unit
            }
            updateButtons()
        }) {
            playing = false
            status.text = "无法启动播放。"
            updateButtons()
        }
    }

    private fun stop() {
        if (recording) recorder.stop()
        if (playing) player.stop()
    }

    private fun updateButtons() {
        recordButton.isEnabled = !recording && !playing
        playButton.isEnabled = !recording && !playing && latest != null
        stopButton.isEnabled = recording || playing
    }

    override fun onStop() { stop(); super.onStop() }
}
