//
//  BackgroundCacheManager.swift
//  NightwavePlaza
//
//  Created by Aleksey Garbarev on 06.09.2020.
//  Copyright © 2020 Aleksey Garbarev. All rights reserved.
//

import Foundation
import Network
import CryptoKit

class BackgroundCacheManager {
    static let shared = BackgroundCacheManager()
    
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitorQueue")
    
    func getLocalUrl(remoteUrl: URL) async throws -> URL {
        let localUrl = localVideoUrl(for: remoteUrl)
        
        if FileManager.default.fileExists(atPath: localUrl.path) {
            return localUrl
        }
        
        let (tempUrl, _) = try await URLSession.shared.download(from: remoteUrl)
        try? FileManager.default.moveItem(at: tempUrl, to: localUrl)
        return localUrl
    }
    
    private func localVideoUrl(for remoteUrl: URL) -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("backgroundVideos")
        
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        
        var pathExt = remoteUrl.pathExtension
        if pathExt.isEmpty {
            pathExt = "mp4"
        }
        
        let inputData = Data(remoteUrl.absoluteString.utf8)
        let hash = SHA256.hash(data: inputData).compactMap { String(format: "%02x", $0) }.joined()
        
        return dir.appendingPathComponent("\(hash).\(pathExt)")
    }    
}
