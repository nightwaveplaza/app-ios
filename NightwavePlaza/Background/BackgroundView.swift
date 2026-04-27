//
//  BackgroundView.swift
//  NightwavePlaza
//
//  Created by Aleksey Garbarev on 24.05.2020.
//  Copyright © 2020 Aleksey Garbarev. All rights reserved.
//

import UIKit
import AVFoundation
import Combine

class BackgroundView: UIView {
    
    private var player = AVPlayer()
    private var pendingPlayer: AVPlayer?
    private var playerLayer = AVPlayerLayer()
    private var solidColor = UIColor(named: "008B8B")
    private var cache = BackgroundCacheManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var downloadTask: Task<Void, Never>?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        
        self.backgroundColor = self.solidColor
        self.layer.addSublayer(playerLayer)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        
        NotificationCenter.default.addObserver(self,
           selector: #selector(playerItemDidReachEnd(notification:)),
           name: .AVPlayerItemDidPlayToEndTime,
           object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeForeground(notification:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    func setUrl(url: URL) {
        downloadTask?.cancel()
        downloadTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let localUrl = try await self.cache.getLocalUrl(remoteUrl: url)
                
                guard !Task.isCancelled else { return }
                
                self.setLocalUrl(url: localUrl)
                
            } catch {
                if !Task.isCancelled {
                    print("Failed to prepare background video: \(error)")
                    self.setSolid()
                }
            }
        }
    }
    
    func setSolid() {
        self.backgroundColor = .clear
        downloadTask?.cancel()
        downloadTask = nil
        
        player.pause()
        player.replaceCurrentItem(with: nil)
        
        pendingPlayer?.pause()
        pendingPlayer?.replaceCurrentItem(with: nil)
        pendingPlayer = nil
        
        cancellables.removeAll()
        
        playerLayer.isHidden = true
        playerLayer.player = nil
    }
    
    func setLocalUrl(url: URL) {
        self.backgroundColor = UIColor.black
        playerLayer.isHidden = false
        
        pendingPlayer?.pause()
        pendingPlayer?.replaceCurrentItem(with: nil)
        cancellables.removeAll()
        
        let nextPlayer = AVPlayer(url: url)
        nextPlayer.actionAtItemEnd = .none
        self.pendingPlayer = nextPlayer
        
        self.startPlayer(player: nextPlayer) { [weak self] in
            guard let self = self else { return }
            
            self.replacePlayer(player: nextPlayer)
            self.pendingPlayer = nil
        }
    }
    
    private func startPlayer(player: AVPlayer, completion: @escaping () -> ()) {
        player.play()
        player.publisher(for: \.timeControlStatus)
            .sink { [weak self] status in
                if status == .playing {
                    completion()
                    self?.cancellables.removeAll()
                }
            }
            .store(in: &cancellables)
    }
    
    func replacePlayer(player: AVPlayer) {
        let newPlayerLayer = AVPlayerLayer(player: player)
        newPlayerLayer.videoGravity = .resizeAspectFill
        newPlayerLayer.magnificationFilter = .nearest
        newPlayerLayer.opacity = 1
        newPlayerLayer.frame = self.bounds
        self.layer.addSublayer(newPlayerLayer)
        
        CATransaction.begin()
        
        let fadeIn = CABasicAnimation.init(keyPath: "opacity")
        fadeIn.toValue = 1
        fadeIn.fromValue = 0
        fadeIn.duration = 0.3
        fadeIn.fillMode = .forwards
        fadeIn.isRemovedOnCompletion = true
        
        let fadeOut = CABasicAnimation.init(keyPath: "opacity")
        fadeOut.toValue = 0
        fadeOut.duration = 0.3
        
        self.playerLayer.add(fadeOut, forKey: "opacity")
        newPlayerLayer.add(fadeIn, forKey: "opacity")
        
        CATransaction.setCompletionBlock({
            self.playerLayer.removeFromSuperlayer()
            self.playerLayer = newPlayerLayer
            self.player = player
        })
        CATransaction.commit()
        
        playerLayer.videoGravity = .resizeAspectFill
    }
    
    @objc func playerItemDidReachEnd(notification: Notification) {
        self.player.seek(to: CMTime.zero)
    }
    
    @objc func didBecomeForeground(notification: Notification) {
        player.rate = 1.0
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = self.bounds
    }
    
}
