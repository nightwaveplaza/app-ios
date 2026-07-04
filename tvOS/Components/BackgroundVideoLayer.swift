//
//  BackgroundVideoLayer.swift
//  NightwavePlaza tvOS
//

import SwiftUI
import AVFoundation

/// Edge-to-edge video background with gradient mask and dimming overlay.
struct BackgroundVideoLayer: View {
    @ObservedObject var backgroundService: BackgroundService
    var showGradient: Bool = true

    @Environment(\.scenePhase) private var scenePhase

    @State private var player = AVPlayer()
    @State private var bgLoopObserver: Any?
    @State private var playerFailed = false
    @State private var currentPlayingURL: URL?

    private let dimmingOpacity: CGFloat = 0.45

    var body: some View {
        ZStack {
            // Video layer — hide during background to avoid _UIReplicantView snapshot issues
            if let url = backgroundService.currentVideoURL, !playerFailed, scenePhase == .active {
                VideoPlayerView(player: player)
                    .ignoresSafeArea()
                    .onAppear { play(url: url) }
            } else {
                fallbackColor
            }

            // Gradient mask + dimming
            if showGradient {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .black.opacity(0.6), location: 0.0),
                        .init(color: .black.opacity(0.0), location: 1.0),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                Color.black.opacity(dimmingOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: backgroundService.currentBackground) { _ in
            if let url = backgroundService.currentVideoURL {
                playerFailed = false
                play(url: url)
            }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                // App returned to foreground — restart video
                if let url = currentPlayingURL ?? backgroundService.currentVideoURL {
                    playerFailed = false
                    play(url: url)
                }
            case .background, .inactive:
                // Going to background — pause to avoid snapshot issues
                cleanupPlayer()
            @unknown default:
                break
            }
        }
        .onDisappear {
            cleanupPlayer()
        }
    }

    private var fallbackColor: some View {
        Color(red: 0.05, green: 0.15, blue: 0.15)
            .ignoresSafeArea()
    }

    private func play(url: URL) {
        cleanupPlayer()
        currentPlayingURL = url

        let item = AVPlayerItem(url: url)

        // Observe load failures
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if item.status == .failed {
                print("[BackgroundVideoLayer] Video load failed: \(item.error?.localizedDescription ?? "unknown")")
                playerFailed = true
            }
        }

        player.replaceCurrentItem(with: item)
        player.play()

        bgLoopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }

    private func cleanupPlayer() {
        if let observer = bgLoopObserver {
            NotificationCenter.default.removeObserver(observer)
            bgLoopObserver = nil
        }
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
}

/// UIViewRepresentable wrapping AVPlayerLayer.
private struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView(player: player)
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }

    static func dismantleUIView(_ uiView: PlayerUIView, coordinator: ()) {
        // Detach player before the view is removed from hierarchy
        uiView.detachPlayer()
    }
}

private final class PlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()

    init(player: AVPlayer) {
        super.init(frame: .zero)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func detachPlayer() {
        playerLayer.player = nil
    }

    var player: AVPlayer {
        get { playerLayer.player! }
        set { playerLayer.player = newValue }
    }
}
