//
//  ArtworkLockup.swift
//  NightwavePlaza tvOS
//

import SwiftUI
import MediaPlayer

/// Album artwork using the borderless button style for the standard tvOS lockup effect.
struct ArtworkLockup: View {
    let artwork: UIImage?
    let size: CGFloat
    var action: (() -> Void)?

    var body: some View {
        if #available(tvOS 17.0, *) {
            Button(action: { action?() }) {
                artworkContent
            }
            .buttonStyle(.borderless)
            .frame(width: size, height: size)
        } else {
            Button(action: { action?() }) {
                artworkContent
            }
            .buttonStyle(.plain)
            .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private var artworkContent: some View {
        if let image = artwork {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(1.0, contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.25))
                        .foregroundColor(.white.opacity(0.4))
                )
        }
    }
}

#if DEBUG
#Preview("Artwork - Placeholder") {
    ArtworkLockup(artwork: nil, size: 300)
}

#Preview("Artwork - With Image") {
    ArtworkLockup(artwork: UIImage(systemName: "music.note"), size: 300)
}
#endif
