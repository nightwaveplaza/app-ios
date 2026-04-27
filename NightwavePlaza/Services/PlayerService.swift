//
//  PlayerService.swift
//  NightwavePlaza
//
//  Created by Alexander on 27.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer
import Combine
import Network

class PlayerService: NSObject {
    let playbackRate = CurrentValueSubject<Float, Never>(0)
    
    private var player: AVPlayer
    private var syncManager: MetadataSyncManager!
    
    private let monitor = NWPathMonitor()
    private var cancellables = Set<AnyCancellable>()
    
    var isLowQualityAudio: Bool = false
    
    private var currentStreamTitle: String?
    private var currentStreamArtist: String?
    
    private let streamURL = URL(string: "https://radio.plaza.one/hls.m3u8")!
    
    @Published var isPlaying: Bool = false
    private var timeControlObservation: NSKeyValueObservation?
    
    override init() {
        self.player = AVPlayer()
        self.player.automaticallyWaitsToMinimizeStalling = true
        
        super.init()
        
        self.syncManager = MetadataSyncManager(playerService: self)
        
        setupAudioSession()
        setupRemoteTransportControls()
        observeNetworkChanges()
        observePlayerState()
        
        setupPlayerItem()
        setupPlayerObservation()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
    }
    
    private func setupPlayerObservation() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            self?.isPlaying = (player.timeControlStatus == .playing)
        }
    }
    
    
    func play() {
        if player.currentItem?.status == .failed || player.status == .failed {
           setupPlayerItem()
        }
        
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    // MARK: - Core Playback & Quality
    private func setupPlayerItem() {
        let item = AVPlayerItem(url: streamURL)
        item.preferredPeakBitRate = isLowQualityAudio ? 70400 : 0
        
        let metadataOutput = AVPlayerItemMetadataOutput()
        metadataOutput.setDelegate(self, queue: DispatchQueue.main)
        item.add(metadataOutput)
        
        player.replaceCurrentItem(with: item)
        
        cancellables.removeAll()
        observePlayerState()

    }
    
    // MARK: - Network (NWPathMonitor)
    private func observeNetworkChanges() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            if path.status == .satisfied {
                DispatchQueue.main.async {
                    if self.player.status == .failed || self.player.currentItem?.status == .failed {
                        let wasPlaying = self.isPlaying
                        self.setupPlayerItem()
                        if wasPlaying {
                            self.play()
                        }
                    }
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }
    
    // MARK: - Reactive State (Combine)
    private func observePlayerState() {
        player.publisher(for: \.rate)
            .sink { [weak self] rate in
                self?.playbackRate.send(rate)
                Settings.isPlaying = (rate > 0)
            }
            .store(in: &cancellables)
    }

    // MARK: - Audio Session (Audio Focus)
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Lockscreen Controls
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying {
                self.play()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isPlaying {
                self.pause()
                return .success
            }
            return .commandFailed
        }
    }
    
    // MARK: - Lockscreen Metadata
    @MainActor
    func updateMetadata(title: String, artist: String, coverUrl: URL?) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        
        if let url = coverUrl {
            Task.detached {
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                    await MainActor.run { MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo }
                }
            }
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }

    // MARK: - Interruptions
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        if type == .began {
            pause()
        } else if type == .ended {
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            if AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                play()
            }
        }
    }
}

extension PlayerService: AVPlayerItemMetadataOutputPushDelegate {
    
    func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup], from track: AVPlayerItemTrack?) {
        guard let group = groups.first else { return }
        
        var newTitle: String?
        var newArtist: String?
        
        for item in group.items {
            let key = item.identifier?.rawValue
            
            if key == "id3/TIT2" {
                newTitle = item.stringValue
            } else if key == "id3/TPE1" {
                newArtist = item.stringValue
            }
        }
        
        guard let title = newTitle, let artist = newArtist else { return }
        
        if title != currentStreamTitle || artist != currentStreamArtist {
            print("Stream metadata changed: \(artist) - \(title)")
            
            currentStreamTitle = title
            currentStreamArtist = artist
            
            Task {
                await syncManager.fetchAndUpdate()
            }
        }
    }
}
