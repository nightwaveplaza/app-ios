//
//  BackgroundService.swift
//  NightwavePlaza tvOS
//

import Foundation
import Combine

@MainActor
class BackgroundService: ObservableObject {
    static let shared = BackgroundService()

    @Published var backgrounds: [Background] = []
    @Published var currentBackground: Background?

    private var currentIndex: Int = 0

    private init() {}

    func fetchBackgrounds() async {
        do {
            let wrapper: BackgroundResponse = try await APIClient.shared.request(path: "backgrounds")
            let result = wrapper.data
            print("[BackgroundService] Fetched \(result.count) backgrounds")
            self.backgrounds = result

            if !result.isEmpty {
                let randomIndex = Int.random(in: 0..<result.count)
                self.currentIndex = randomIndex
                self.currentBackground = result[randomIndex]
                print("[BackgroundService] Selected background #\(result[randomIndex].id): \(result[randomIndex].filename) video=\(result[randomIndex].videoSrc)")
            } else {
                print("[BackgroundService] WARNING: backgrounds array is empty")
            }
        } catch {
            print("[BackgroundService] ERROR fetching backgrounds: \(error)")
        }
    }

    func nextBackground() {
        guard !backgrounds.isEmpty else {
            print("[BackgroundService] nextBackground: no backgrounds loaded")
            return
        }
        currentIndex = (currentIndex + 1) % backgrounds.count
        currentBackground = backgrounds[currentIndex]
        print("[BackgroundService] Switched to background #\(currentBackground!.id): \(currentBackground!.filename)")
    }

    func previousBackground() {
        guard !backgrounds.isEmpty else {
            print("[BackgroundService] previousBackground: no backgrounds loaded")
            return
        }
        currentIndex = (currentIndex - 1 + backgrounds.count) % backgrounds.count
        currentBackground = backgrounds[currentIndex]
        print("[BackgroundService] Switched to background #\(currentBackground!.id): \(currentBackground!.filename)")
    }

    func randomBackground() {
        guard !backgrounds.isEmpty else { return }
        currentIndex = Int.random(in: 0..<backgrounds.count)
        currentBackground = backgrounds[currentIndex]
    }

    var currentVideoURL: URL? {
        guard let bg = currentBackground else {
            print("[BackgroundService] currentVideoURL: currentBackground is nil")
            return nil
        }
        guard let url = URL(string: bg.videoSrc) else {
            print("[BackgroundService] currentVideoURL: invalid URL from '\(bg.videoSrc)'")
            return nil
        }
        return url
    }

    var currentAuthor: String? {
        guard let bg = currentBackground, !bg.author.isEmpty else { return nil }
        return bg.author
    }

    var currentSource: String? {
        guard let bg = currentBackground, !bg.source.isEmpty else { return nil }
        return bg.source
    }
}
