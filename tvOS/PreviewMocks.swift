//
//  PreviewMocks.swift
//  NightwavePlaza tvOS
//

import SwiftUI

#if DEBUG

/// Wraps preview content with mock services so previews don't hit the network.
struct PreviewContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        setupMockData()
    }

    var body: some View {
        content
            .environmentObject(PlayerService.shared)
            .environmentObject(BackgroundService.shared)
    }

    @MainActor
    private func setupMockData() {
        let service = BackgroundService.shared
        guard service.backgrounds.isEmpty else { return } // only inject once
        service.backgrounds = [
            Background(id: 1, filename: "sunset", src: "", videoSrc: "", author: "Photographer", authorLink: "", source: "Unsplash", sourceLink: ""),
            Background(id: 2, filename: "city", src: "", videoSrc: "", author: "Artist", authorLink: "", source: "Pexels", sourceLink: ""),
        ]
        service.currentBackground = service.backgrounds.first
    }
}

#endif
