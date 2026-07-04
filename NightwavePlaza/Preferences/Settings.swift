//
//  Settings.swift
//  NightwavePlaza
//
//  Created by Alexander on 25.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//

import Foundation

enum Settings {

    @AppPreference(key: "sleepTargetTimer", defaultValue: 0)
    static var sleepTargetTime: Int
    
    @AppPreference(key: "UserToken", defaultValue: "")
    static var userToken: String
    
    @AppPreference(key: "Fullscreen", defaultValue: false)
    static var fullScreen: Bool
    
    @AppPreference(key: "AudioLowQuality", defaultValue: false)
    static var lowQualityAudio: Bool
    
    @AppPreference(key: "ThemeColor", defaultValue: "#c0c0c0")
    static var themeColor: String
    
    @AppPreference(key: "Language", defaultValue: defaultLanguage)
    static var language: String
    
    // Get default language
    static var defaultLanguage: String {
        if #available(iOS 16, tvOS 16, *) {
            return Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            return Locale.current.languageCode ?? "en"
        }
    }

    @AppPreference(key: "VideoBackgroundEnabled", defaultValue: true)
    static var videoBackgroundEnabled: Bool

    @AppPreference(key: "DisableSwipeToChange", defaultValue: false)
    static var disableSwipeToChange: Bool

    @AppPreference(key: "SleepTimerMinutes", defaultValue: 0)
    static var sleepTimerMinutes: Int

    @AppPreference(key: "ChangeBackgroundOnNewTrack", defaultValue: true)
    static var changeBackgroundOnNewTrack: Bool
}
