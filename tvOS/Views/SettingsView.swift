//
//  SettingsView.swift
//  NightwavePlaza tvOS
//

import SwiftUI

struct SettingsView: View {
    @Namespace private var focusNamespace

    // Local bindings for toggles so changes are immediate
    @State private var lowQualityAudio: Bool = Settings.lowQualityAudio
    @State private var videoBackground: Bool = Settings.videoBackgroundEnabled
    @State private var disableSwipe: Bool = Settings.disableSwipeToChange
    @State private var changeBgOnTrack: Bool = Settings.changeBackgroundOnNewTrack
    @State private var sleepTimerMinutes: Int = Settings.sleepTimerMinutes

    private let sleepTimerOptions: [(label: String, minutes: Int)] = [
        ("Off", 0),
        ("15 minutes", 15),
        ("30 minutes", 30),
        ("1 hour", 60),
        ("2 hours", 120),
    ]

    var body: some View {
        Form {
            // Audio section
            Section {
                Toggle("Low Quality Audio", isOn: $lowQualityAudio)
                    .onChange(of: lowQualityAudio) { newValue in
                        Settings.lowQualityAudio = newValue
                    }
            } header: {
                Text("Audio")
            }

            // Background section
            Section {
                Toggle("Video Background", isOn: $videoBackground)
                    .onChange(of: videoBackground) { newValue in
                        Settings.videoBackgroundEnabled = newValue
                    }

                Toggle("Disable Swipe to Change Background", isOn: $disableSwipe)
                    .onChange(of: disableSwipe) { newValue in
                        Settings.disableSwipeToChange = newValue
                    }

                Toggle("Change Background on New Track", isOn: $changeBgOnTrack)
                    .onChange(of: changeBgOnTrack) { newValue in
                        Settings.changeBackgroundOnNewTrack = newValue
                    }
            } header: {
                Text("Background")
            }

            // Sleep section
            Section {
                Picker("Sleep Timer", selection: $sleepTimerMinutes) {
                    ForEach(sleepTimerOptions, id: \.minutes) { option in
                        Text(option.label).tag(option.minutes)
                    }
                }
                .onChange(of: sleepTimerMinutes) { newValue in
                    Settings.sleepTimerMinutes = newValue
                    scheduleSleepTimer(minutes: newValue)
                }
            } header: {
                Text("Sleep")
            }
        }
        .focusScope(focusNamespace)
    }

    private func scheduleSleepTimer(minutes: Int) {
        if minutes > 0 {
            let timestamp = Date().timeIntervalSince1970 + Double(minutes * 60)
            SleepTimerService.shared.sleepAt(timestamp: timestamp * 1000)
        }
    }
}

#if DEBUG
#Preview("Settings") {
    PreviewContainer {
        SettingsView()
    }
}
#endif
