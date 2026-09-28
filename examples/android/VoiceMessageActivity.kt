// Copy this into an Android Activity after requesting RECORD_AUDIO at runtime.
import com.thk.oggopus.OggOpusPlayer
import com.thk.oggopus.OggOpusRecorder
import com.thk.oggopus.OggOpusState
import java.io.File

fun recordVoiceMessage() {
    val path = File(filesDir, "voice.ogg").absolutePath
    val player = OggOpusPlayer(applicationContext)
    OggOpusRecorder(applicationContext).start(path, 60_000) { event ->
        if (event.state == OggOpusState.FINISHED) player.play(event.path)
    }
}

