//
//  TransportControl.swift
//  NightwavePlaza tvOS
//

import SwiftUI

/// Play/pause button with CardButtonStyle for tvOS raised platter + directional movement.
struct TransportControl: View {
    @EnvironmentObject var playerService: PlayerService
    var namespace: Namespace.ID

    var body: some View {
        Button(action: togglePlayback) {
            HStack(spacing: 12) {
                Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 24)
        }
        .buttonStyle(CardButtonStyle())
    }

    private func togglePlayback() {
        if playerService.isPlaying {
            playerService.pause()
        } else {
            playerService.play()
        }
    }
}

#if DEBUG
#Preview("Transport - Paused") {
    PreviewContainer {
        TransportControlPreview()
    }
}

private struct TransportControlPreview: View {
    @Namespace var ns
    var body: some View {
        TransportControl(namespace: ns)
    }
}
#endif
