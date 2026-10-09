import AVFoundation
import AVKit
import SwiftUI
import UIKit

@MainActor
final class KeyboardSetupGuideVideoCoordinator: NSObject, ObservableObject {
    enum Purpose { case enablement, fullAccess }
    @Published private(set) var isOpeningSettings = false
    private let purpose: Purpose
    var isAvailable: Bool { videoURL != nil }
    private var guideAttemptID: String?

    init(purpose: Purpose = .fullAccess) {
        self.purpose = purpose
        super.init()
    }

    private var player: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var pictureInPictureController: AVPictureInPictureController?
    private var pendingSettingsOpen: (() -> Void)?
    private var fallbackWorkItem: DispatchWorkItem?
    private var settingsOpenID: UUID?

    func attach(to playerLayer: AVPlayerLayer) {
        guard player == nil, let url = videoURL else { return }

        let player = AVQueuePlayer()
        player.actionAtItemEnd = .none
        player.isMuted = true
        playerLooper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        self.player = player

        if AVPictureInPictureController.isPictureInPictureSupported() {
            let controller = AVPictureInPictureController(playerLayer: playerLayer)
            controller?.delegate = self
            controller?.requiresLinearPlayback = true
            pictureInPictureController = controller
        }

        player.play()
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func openSettingsWithPictureInPicture(_ openSettings: @escaping () -> Void) {
        guard !isOpeningSettings else { return }
        isOpeningSettings = true
        guideAttemptID = UUID().uuidString.lowercased()
        report("requested")
        player?.seek(to: .zero)
        player?.play()
        guard let controller = pictureInPictureController else {
            report("pip_unavailable")
            openSettings()
            return
        }

        pendingSettingsOpen = openSettings
        let requestID = UUID()
        settingsOpenID = requestID
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: .mixWithOthers)
        try? session.setActive(true)

        if controller.isPictureInPicturePossible {
            startPictureInPicture(controller)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self, weak controller] in
                guard let self, let controller, self.settingsOpenID == requestID else { return }
                if controller.isPictureInPicturePossible {
                    self.startPictureInPicture(controller)
                } else {
                    self.report("pip_not_ready")
                    self.completeSettingsOpen()
                }
            }
        }
    }

    private func startPictureInPicture(_ controller: AVPictureInPictureController) {
        controller.startPictureInPicture()

        let fallback = DispatchWorkItem { [weak self] in
            self?.report("pip_start_timeout")
            self?.completeSettingsOpen()
        }
        fallbackWorkItem = fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: fallback)
    }

    func stopPictureInPicture() {
        isOpeningSettings = false
        if pictureInPictureController?.isPictureInPictureActive == true {
            pictureInPictureController?.stopPictureInPicture()
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func stop() {
        pendingSettingsOpen = nil
        settingsOpenID = nil
        fallbackWorkItem?.cancel()
        fallbackWorkItem = nil
        stopPictureInPicture()
        pause()
    }

    private func completeSettingsOpen() {
        fallbackWorkItem?.cancel()
        fallbackWorkItem = nil
        let action = pendingSettingsOpen
        pendingSettingsOpen = nil
        settingsOpenID = nil
        action?()
    }

    private func report(_ outcome: String) {
        OnboardingDiagnostics.capture("keyboard_setup_guide", step: purpose == .enablement ? "keyboard_setup" : "full_access", properties: [
            "guide_attempt_id": guideAttemptID ?? "unknown", "outcome": outcome,
            "video_available": isAvailable,
        ])
    }

    private var videoURL: URL? {
        let preferred = Bundle.main.preferredLocalizations.first ?? "ja"
        let language = preferred.hasPrefix("zh") ? "zh-Hans" : preferred.hasPrefix("en") ? "en" : "ja"
        let prefix = purpose == .enablement ? "keyboard-enable" : "keyboard-setup"
        return Bundle.main.url(forResource: "\(prefix)-\(language)", withExtension: "mp4")
    }
}

extension KeyboardSetupGuideVideoCoordinator: @preconcurrency AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        report("pip_started")
        completeSettingsOpen()
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: any Error
    ) {
        report("pip_failed")
        completeSettingsOpen()
    }
}

struct KeyboardSetupGuideVideoView: UIViewRepresentable {
    let coordinator: KeyboardSetupGuideVideoCoordinator

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        coordinator.attach(to: view.playerLayer)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        coordinator.play()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }
    }
}
