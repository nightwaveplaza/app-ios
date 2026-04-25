//
//  Settings.swift
//  NightwavePlaza
//
//  Created by Alexander on 25.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//

import Foundation

enum Settings {
    
    @AppPreference(key: "IsPlaying", defaultValue: false)
    static var isPlaying: Bool

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
    
    #if DEBUG
    static let isDevChannelDefault = true
    #else
    static let isDevChannelDefault = false
    #endif
    
    @AppPreference(key: "DevChannel", defaultValue: isDevChannelDefault)
    static var useDevChannel: Bool
}
