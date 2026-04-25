//
//  PlaybackService.swift
//  NightwavePlaza
//
//  Created by Aleksey Garbarev on 24.05.2020.
//  Copyright © 2020 Aleksey Garbarev. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer
import RxSwift
import RxCocoa
import Reachability

enum PlaybackQuality: Int {
    case High = 0
    case Eco = 1
}

class PlaybackService {    
    var playbackRate$ = BehaviorSubject<Float>(value: 0)
    
    var player = AVPlayer(url: URL(string: "https://radio.plaza.one/mp3")!)
    
    let reachability = try! Reachability()
    
    private var lastPlayTime: CMTime?

    init() {
        self.setupPlaybackSession()
        self.setupRemoteTransportControls()

        self.replacePlayerForQuality()
        self.resumePlaybackWhenBecomeReachable()

        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(notification:)), name: AVAudioSession.interruptionNotification, object: nil)
    }
    

    func resumePlaybackWhenBecomeReachable() {
        
        reachability.whenReachable = { [unowned self] reachability in
            self.replacePlayerForQuality()
        }
        
        do {
            try reachability.startNotifier()
        } catch {
            // TODO
        }
        
    }
    
    func play() {
        if let lastTime = self.lastPlayTime, CMTimeCompare(player.currentTime(), lastTime) == 0 {
            // If player stalled, reload player
            self.replacePlayerForQuality()
        }
        
        player.play()
        self.playbackRate$.onNext(player.rate)
        self.lastPlayTime = player.currentTime()
    }
    
    func pause() {
        player.pause()
        self.playbackRate$.onNext(player.rate)
        self.lastPlayTime = player.currentTime()
    }
    
    var paused: Bool {
        get {
            return self.player.timeControlStatus == AVPlayer.TimeControlStatus.paused
        }
    }
    
    func replacePlayerForQuality() {
        let rate = self.player.rate;
        self.player.pause()
        self.player = AVPlayer(url: self.urlForQuality())
        self.player.rate = rate
    }
    
    private func urlForQuality() -> URL {
        Settings.lowQualityAudio ? URL(string: "https://radio.plaza.one/mp3_low")! : URL(string: "https://radio.plaza.one/mp3")!
    }
    
    @objc private func handleInterruption(notification: NSNotification) {
        
        guard let userInfo = notification.userInfo,
            let interruptionTypeRawValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeRawValue) else {
                print("Unable to parse interruptionType")
                self.pause()
                return
        }
    
        switch interruptionType {
        case .began:
            self.pause()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                self.play()
            } else {
                print("Should NOT resume a playback")
                // Interruption ended. Playback should not resume.
            }
        }
        
    }
    
    private func setupPlaybackSession() {
       
        let session = AVAudioSession.sharedInstance()
        
        do {
            if #available(iOS 13.0, *) {
                try session.setCategory(AVAudioSession.Category.playback,
                                        mode: .default,
                                        policy: .longFormAudio,
                                        options: [])
            } else {
                try session.setCategory(AVAudioSession.Category.playback, options: [])
            }
        } catch let error {
            fatalError("*** Unable to set up the audio session: \(error.localizedDescription) ***")
        }
        do {
            try session.setActive(true)
        } catch let error {
            fatalError("Unable to active audio session: \(error.localizedDescription)")
        }
    }
    
    private func setupRemoteTransportControls() {
        
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [unowned self] event in
            if self.player.rate == 0.0 {
                self.play()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            if self.player.rate == 1.0 {
                self.pause()
                return .success
            }
            return .commandFailed
        }
    }
}
