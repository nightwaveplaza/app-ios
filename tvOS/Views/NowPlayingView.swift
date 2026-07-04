//
//  NowPlayingView.swift
//  NightwavePlaza tvOS
//

import SwiftUI
import MediaPlayer
import Combine

/// Focused-mode Now Playing overlay — background is handled by ContentView.
struct NowPlayingView: View {
    @EnvironmentObject var playerService: PlayerService
    @EnvironmentObject var backgroundService: BackgroundService
    @Binding var isMinimal: Bool

    @Namespace private var focusNamespace
    @Environment(\.resetFocus) var resetFocus

    @State private var nowPlayingInfo: [String: Any] = [:]
    @State private var cancellables = Set<AnyCancellable>()
    @State private var lastTrackTitle: String = ""

    private var trackTitle: String {
        nowPlayingInfo[MPMediaItemPropertyTitle] as? String ?? "Nightwave Plaza"
    }

    private var trackArtist: String {
        nowPlayingInfo[MPMediaItemPropertyArtist] as? String ?? ""
    }

    private var artworkImage: UIImage? {
        guard let artwork = nowPlayingInfo[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork else {
            return nil
        }
        return artwork.image(at: CGSize(width: 500, height: 500))
    }

    private var statusText: String {
        if playerService.isBuffering { return "Buffering..." }
        return ""
    }

    private var hasNowPlaying: Bool { !nowPlayingInfo.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Artwork — always in view tree for focus; invisible when idle
            ArtworkLockup(artwork: artworkImage, size: 500) {
                isMinimal.toggle()
            }
            .opacity(hasNowPlaying ? 1 : 0)
            .disabled(!hasNowPlaying)
            .prefersDefaultFocus(hasNowPlaying, in: focusNamespace)

            // Track title
            Text(hasNowPlaying ? trackTitle : "Nightwave Plaza")
                .font(.system(size: hasNowPlaying ? 36 : 40, weight: .bold))
                .foregroundColor(.white.opacity(hasNowPlaying ? 1 : 0.6))
                .padding(.top, hasNowPlaying ? 40 : 30)
                .padding(.horizontal, 60)
                .animation(.none, value: hasNowPlaying)

            // Artist name
            Text(trackArtist)
                .font(.system(size: 24, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 12)
                .padding(.horizontal, 60)
                .opacity(hasNowPlaying && !trackArtist.isEmpty ? 1 : 0)

            // Status
            if hasNowPlaying {
                Text(statusText)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 30)
            }

            Spacer()

            // Transport control
            TransportControl(namespace: focusNamespace)
                .prefersDefaultFocus(!hasNowPlaying, in: focusNamespace)
                .padding(.bottom, 40)

            // Background info
            backgroundInfoLabel
                .padding(.bottom, 30)
        }
        .focusScope(focusNamespace)
        .onAppear { observeNowPlaying() }
        .onChange(of: trackTitle) { newTitle in
            guard Settings.changeBackgroundOnNewTrack else { return }
            if !lastTrackTitle.isEmpty, newTitle != lastTrackTitle {
                backgroundService.nextBackground()
            }
            lastTrackTitle = newTitle
        }
        .onChange(of: hasNowPlaying) { appeared in
            if appeared { resetFocus(in: focusNamespace) }
        }
        .onMoveCommand { direction in
            guard !Settings.disableSwipeToChange else { return }
            switch direction {
            case .left:  backgroundService.previousBackground()
            case .right: backgroundService.nextBackground()
            default: break
            }
        }
    }

    @ViewBuilder
    private var backgroundInfoLabel: some View {
        let author = backgroundService.currentAuthor
        let source = backgroundService.currentSource
        if author != nil || source != nil {
            let text = [author, source].compactMap { $0 }.joined(separator: " — ")
            Text(text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 60)
        }
    }

    private func observeNowPlaying() {
        MPNowPlayingInfoCenter.default().publisher(for: \.nowPlayingInfo)
            .receive(on: DispatchQueue.main)
            .sink { info in
                if let info = info { nowPlayingInfo = info }
            }
            .store(in: &cancellables)
    }
}

#if DEBUG
#Preview("Now Playing - Idle") {
    PreviewContainer {
        NowPlayingView(isMinimal: .constant(false))
    }
}
#endif
