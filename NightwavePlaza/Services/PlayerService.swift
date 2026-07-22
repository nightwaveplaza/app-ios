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
    static let shared = PlayerService()
    
    // MARK: - State
    let playbackRate = CurrentValueSubject<Float, Never>(0)
    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    private var userIntentToPlay: Bool = false
    
    // MARK: - Core Components
    private var player: AVPlayer
    private var syncManager: MetadataSyncManager!
    
    // MARK: - Observers
    private let monitor = NWPathMonitor()
    private var cancellables = Set<AnyCancellable>()
    private var timeControlObservation: NSKeyValueObservation?
    
    // MARK: - Playback Data
    private var currentStreamTitle: String?
    private var currentStreamArtist: String?
    private var songEstimatedStartTime: TimeInterval?
    
    private let streamURL = URL(string: "https://radio.plaza.one/hls.m3u8")!
    
    override init() {
        self.player = AVPlayer()
        // Ensure smooth playback by buffering sufficient data before starting
        self.player.automaticallyWaitsToMinimizeStalling = true
        
        super.init()
        
        self.syncManager = MetadataSyncManager(playerService: self)
        
        setupAudioSession()
        setupRemoteTransportControls()
        observeNetworkChanges()
        observePlayerState()
        
        setupPlayerObservation()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    private func setupPlayerObservation() {
        // Keep internal playing state in sync with the actual audio engine
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            guard let self = self else { return }
            self.isPlaying = (player.timeControlStatus == .playing)
            self.isBuffering = (player.timeControlStatus == .waitingToPlayAtSpecifiedRate)
        }
    }
    
    
    func play() {
        userIntentToPlay = true
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
        
        // Recover playback if the stream chunk failed (e.g. after a long pause or network drop)
        if player.currentItem == nil || player.currentItem?.status == .failed || player.status == .failed {
            setupPlayerItem()
        }
        
        player.play()
    }
    
    func pause() {
        userIntentToPlay = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        
        // Release the audio focus for other apps
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    // MARK: - Core Playback & Quality
    private func setupPlayerItem() {
        let item = AVPlayerItem(url: streamURL)
        
        // Limit bandwidth for low-quality mode
        item.preferredPeakBitRate = Settings.lowQualityAudio ? 70400 : 0
        
        // Listen for embedded ID3 metadata tags in the HLS stream
        let metadataOutput = AVPlayerItemMetadataOutput()
        metadataOutput.setDelegate(self, queue: DispatchQueue.main)
        item.add(metadataOutput)
        
        player.replaceCurrentItem(with: item)
        
        // Reset state subscriptions for the new track
        cancellables.removeAll()
        observePlayerState()

    }
    
    // MARK: - Network (NWPathMonitor)
    private func observeNetworkChanges() {
        // Automatically resume playback if the connection is restored and the player previously failed
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            if path.status == .satisfied {
                DispatchQueue.main.async {
                    let itemBroken = self.player.currentItem == nil
                        || self.player.currentItem?.status == .failed
                        || self.player.status == .failed

                    if self.userIntentToPlay && itemBroken {
                        print("Network restored. Recovering playback...")
                        self.setupPlayerItem()
                        self.player.play()
                    }
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }
    
    // MARK: - Reactive State
    private func observePlayerState() {
        player.publisher(for: \.rate)
            .sink { [weak self] rate in
                guard let self = self else { return }
                
                self.playbackRate.send(rate)
                
                // Keep the lockscreen progress bar in sync with actual playback (e.g. pausing)
                Task {
                    await self.syncLockscreenPosition(rate: Double(rate))
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func syncLockscreenPosition(rate: Double) {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        
        // Adjust the lockscreen progress bar to compensate for the time spent on pause
        if rate > 0, let startTime = self.songEstimatedStartTime {
            let actualPosition = Date().timeIntervalSince1970 - startTime
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = actualPosition
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // MARK: - Audio Session
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Configure as a continuous media playback app (allows background play)
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Lockscreen Controls
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        
        // Handle 'Play' from lockscreen, Control Center, or Bluetooth headphones
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self, !self.userIntentToPlay else { return .commandFailed }
            DispatchQueue.main.async {
                self.play()
            }
            return .success
        }

         // Gate 'Pause' on the user's intent, not on isPlaying: while the stream
         // is buffering isPlaying is false, but pause must still work
         commandCenter.pauseCommand.addTarget { [weak self] _ in
             guard let self = self, self.userIntentToPlay else { return .commandFailed }
             DispatchQueue.main.async {
                 self.pause()
             }
             return .success
        }

         // A single tap on AirPods / a headset button sends toggle, not play or pause
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            DispatchQueue.main.async {
                if self.userIntentToPlay {
                    self.pause()
                } else {
                    self.play()
                }
            }
            return .success
        }
        
        // Explicitly disable seek/skip controls since this is a live radio stream
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
    }
    
    // MARK: - Lockscreen Metadata
    @MainActor
    func updateMetadata(title: String, artist: String, duration: Double, position: Double, coverUrl: URL?) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = Double(self.player.rate)
        
        // Push text data immediately so the UI updates without waiting for the image
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        // Save the absolute start time for calculating elapsed time after pauses
        self.songEstimatedStartTime = Date().timeIntervalSince1970 - position
        
        if let url = coverUrl {
            Task.detached {
                do {
                    // Download cover art in the background
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
                        
                        await MainActor.run {
                            // Re-fetch the dictionary to avoid overwriting positional updates that might have happened during download
                            var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                            updatedInfo[MPMediaItemPropertyArtwork] = artwork
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                        }
                    }
                } catch {
                    print("Artwork download failed: \(error)")
                }
            }
        }
    }

    // MARK: - Interruptions (Phone calls, alarms, etc.)
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        if type == .began {
            // Pause when a phone call comes in
            pause()
        } else if type == .ended {
            // Resume if the system indicates it's appropriate (e.g. call ended)
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            if AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                play()
            }
        }
    }
    
    // MARK: - Route Changes (Headphones unplugged, Bluetooth disconnected)
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
              reason == .oldDeviceUnavailable else { return }

         // Pause only if the device that disappeared was an external output we were
        let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription
        let wasOnExternalOutput = previousRoute?.outputs.contains { output in
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .usbAudio, .carAudio, .airPlay]
                .contains(output.portType)
         } ?? false

        guard wasOnExternalOutput else { return }

        DispatchQueue.main.async {
            if self.userIntentToPlay {
                self.pause()
            }
        }
    }
}

// MARK: - HLS Metadata Delegate
extension PlayerService: AVPlayerItemMetadataOutputPushDelegate {
    
    func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup], from track: AVPlayerItemTrack?) {
        guard let group = groups.first else { return }
        
        var newTitle: String?
        var newArtist: String?
        
        // Extract track info from embedded ID3 tags
        for item in group.items {
            let key = item.identifier?.rawValue
            
            if key == "id3/TIT2" {
                newTitle = item.stringValue
            } else if key == "id3/TPE1" {
                newArtist = item.stringValue
            }
        }
        
        // Filter duplicates: trigger an API sync only when a new song starts
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
