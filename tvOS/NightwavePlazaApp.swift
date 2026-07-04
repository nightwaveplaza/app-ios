//
//  NightwavePlazaApp.swift
//  NightwavePlaza tvOS
//

import SwiftUI
import Sentry

@main
struct NightwavePlazaApp: App {
    @StateObject private var playerService = PlayerService.shared
    @StateObject private var backgroundService = BackgroundService.shared

    init() {
        setupSentry()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playerService)
                .environmentObject(backgroundService)
        }
    }

    private func setupSentry() {
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String,
              !dsn.isEmpty else {
            print("⚠️ SENTRY_DSN not found. Sentry disabled.")
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.tracesSampleRate = 1.0
        }
    }
}
