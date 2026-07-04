//
//  ContentView.swift
//  NightwavePlaza tvOS
//

import SwiftUI
import MediaPlayer
import Combine

struct ContentView: View {
    @EnvironmentObject var backgroundService: BackgroundService
    @State private var selectedTab = 0
    @State private var isMinimal = false

    var body: some View {
        ZStack {
            // Persistent background layer
            backgroundLayer

            if isMinimal {
                // Minimal: full-screen Now Playing, no tab bar
                MinimalNowPlayingView(isMinimal: $isMinimal)
            } else {
                // Focused: tabbed layout
                TabView(selection: $selectedTab) {
                    NowPlayingView(isMinimal: $isMinimal)
                        .tabItem {
                            Label("Now Playing", systemImage: "play.rectangle")
                        }
                        .tag(0)

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .tag(1)

                    AboutView()
                        .tabItem {
                            Label("About", systemImage: "info.circle")
                        }
                        .tag(2)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isMinimal)
        .onAppear {
            if backgroundService.backgrounds.isEmpty {
                Task { await backgroundService.fetchBackgrounds() }
            }
        }
    }

    // MARK: - Background Layer

    @ViewBuilder
    private var backgroundLayer: some View {
        if Settings.videoBackgroundEnabled {
            BackgroundVideoLayer(backgroundService: backgroundService, showGradient: !isMinimal)
        } else {
            Color(red: 0.05, green: 0.15, blue: 0.15).ignoresSafeArea()
        }
    }
}

// MARK: - Minimal Now Playing Overlay

struct MinimalNowPlayingView: View {
    @EnvironmentObject var playerService: PlayerService
    @EnvironmentObject var backgroundService: BackgroundService
    @Binding var isMinimal: Bool

    @State private var nowPlayingInfo: [String: Any] = [:]
    @State private var cancellables = Set<AnyCancellable>()

    private var trackTitle: String {
        nowPlayingInfo[MPMediaItemPropertyTitle] as? String ?? ""
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

    private var hasNowPlaying: Bool { !nowPlayingInfo.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    ArtworkLockup(artwork: artworkImage, size: 200) {
                        isMinimal.toggle()
                    }
                    .opacity(hasNowPlaying ? 1 : 0)
                    .disabled(!hasNowPlaying)

                    Text(trackTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .opacity(hasNowPlaying ? 1 : 0)

                    Text(trackArtist)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .opacity(hasNowPlaying ? 1 : 0)
                }
                .padding(.top, 60)
                .padding(.leading, 60)
                Spacer()
            }
            Spacer()
        }
        .onAppear { observeNowPlaying() }
        .onMoveCommand { direction in
            guard !Settings.disableSwipeToChange else { return }
            switch direction {
            case .left:  backgroundService.previousBackground()
            case .right: backgroundService.nextBackground()
            default: break
            }
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
#Preview("ContentView") {
    PreviewContainer {
        ContentView()
    }
}
#endif
