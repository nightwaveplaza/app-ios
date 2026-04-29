//
//  MetadataSyncManager.swift
//  NightwavePlaza
//
//  Created by Alexander on 27.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//

import Foundation

actor MetadataSyncManager {
    private var isSyncing = false
    
    private weak var playerService: PlayerService?
    
    init(playerService: PlayerService) {
        self.playerService = playerService
    }
    
    func fetchAndUpdate() async {
        if isSyncing { return }
        isSyncing = true
        
        defer { isSyncing = false }
        
        do {
            let status: Status = try await APIClient.shared.request(path: "status")
            
            if status.song.id.isEmpty { return }
            
            let now = Date().timeIntervalSince1970
            let serverTime = Double(status.updatedAt)
            let networkDelay = now - serverTime
            let safeDelay = max(0, networkDelay)
            
            let duration = Double(status.song.length)
            
            var actualPosition = Double(status.position) + safeDelay
            actualPosition = min(actualPosition, duration)
            
            await playerService?.updateMetadata(
                title: status.song.title,
                artist: status.song.artist,
                duration: duration,
                position: actualPosition,
                coverUrl: URL(string: status.song.artworkSrc)
            )
        } catch {
            print("API sync failed: \(error)")
        }
    }
}
