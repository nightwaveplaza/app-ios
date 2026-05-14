//
//  WebViewCallback.swift
//  NightwavePlaza
//
//  Created by Alexander on 25.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//

protocol WebViewCallback: AnyObject {
    func onPlayAudio()
    func onSetBackground(src: String)
    func onToggleFullscreen()
    func onSetSleepTimer(time: Double)
    func onSetLanguage(lang: String)
    func onReady()
    func onSetThemeColor(color: String)
}
