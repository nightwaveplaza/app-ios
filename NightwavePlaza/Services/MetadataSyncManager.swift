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
            
            await playerService?.updateMetadata(
                title: status.song.title,
                artist: status.song.artist,
                coverUrl: URL(string: status.song.artworkSrc)
            )
        } catch {
            print("API sync failed: \(error)")
        }
    }
}
