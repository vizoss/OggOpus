import UIKit
import AVFoundation
import OggOpus

final class VoiceViewController: UIViewController {
    private enum Mode { case idle, permission, recording, stopping, playing }
    private var mode: Mode = .idle { didSet { updateButtons() } }
    private var file: URL?
    private let status = UILabel()
    private let progress = UILabel()
    private let fileLabel = UILabel()
    private let recordButton = UIButton(type: .system)
    private let stopRecordButton = UIButton(type: .system)
    private let playButton = UIButton(type: .system)
    private let stopPlayButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "OggOpus Demo"
        view.backgroundColor = .systemBackground
        status.text = "点击开始录音，首次使用需要麦克风授权。"
        for label in [status, progress, fileLabel] { label.numberOfLines = 0 }
        progress.textColor = .secondaryLabel
        fileLabel.font = .preferredFont(forTextStyle: .footnote)
        fileLabel.text = "录音保存在应用 Documents 目录。"
        recordButton.setTitle("开始录音（最长 60 秒）", for: .normal)
        stopRecordButton.setTitle("停止录音并保存", for: .normal)
        playButton.setTitle("播放最近录音", for: .normal)
        stopPlayButton.setTitle("停止播放", for: .normal)
        recordButton.addTarget(self, action: #selector(record), for: .touchUpInside)
        stopRecordButton.addTarget(self, action: #selector(stopRecording), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(play), for: .touchUpInside)
        stopPlayButton.addTarget(self, action: #selector(stopPlaying), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [status, progress, recordButton, stopRecordButton, playButton, stopPlayButton, fileLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
        updateButtons()
    }

    private func updateButtons() {
        recordButton.isEnabled = mode == .idle
        stopRecordButton.isEnabled = mode == .recording
        playButton.isEnabled = mode == .idle && file != nil
        stopPlayButton.isEnabled = mode == .playing
    }

    @objc private func record() {
        guard mode == .idle else { return }
        mode = .permission
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
            DispatchQueue.main.async {
                guard let self = self, self.mode == .permission else { return }
                self.mode = .idle
                guard allowed else { self.status.text = "请在系统设置中允许麦克风权限。"; return }
                self.beginRecording()
            }
        }
    }

    private func beginRecording() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("voice-\(UUID().uuidString).ogg")
        mode = .recording
        status.text = "录音中…"
        let started = OggOpusRecorder.shared.startRecording(url.path, 60) { [weak self] db, ms, _, finished in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.progress.text = String(format: "%.1f 秒 · %.1f dB", Double(ms) / 1000, db)
                if finished {
                    if let error = OggOpusRecorder.shared.lastError {
                        self.mode = .idle
                        self.status.text = "录音失败：\(error)"
                        return
                    }
                    self.file = url
                    self.fileLabel.text = url.path
                    self.mode = .idle
                    self.status.text = "录音已保存。"
                }
            }
        }
        if !started { mode = .idle; status.text = "录音启动失败：\(OggOpusRecorder.shared.lastError ?? "未知错误")" }
    }

    @objc private func stopRecording() {
        guard mode == .recording else { return }
        mode = .stopping
        status.text = "正在保存…"
        OggOpusRecorder.shared.stopRecording()
    }

    @objc private func play() {
        guard mode == .idle, let file = file else { return }
        mode = .playing
        status.text = "播放中…"
        let started = OggOpusPlayer.shared.startPlaying(file.path) { [weak self] db, ms, _, finished in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.progress.text = String(format: "%.1f 秒 · %.1f dB", Double(ms) / 1000, db)
                if finished { self.mode = .idle; self.status.text = "播放已结束。" }
            }
        }
        if !started { mode = .idle; status.text = "播放启动失败。" }
    }

    @objc private func stopPlaying() {
        if mode == .playing { OggOpusPlayer.shared.stopPlaying() }
    }

    @objc private func background() {
        if mode == .permission { mode = .idle }
        stopRecording()
        stopPlaying()
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}
