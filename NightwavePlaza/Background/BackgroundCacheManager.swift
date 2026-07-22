//
//  BackgroundCacheManager.swift
//  NightwavePlaza
//
//  Created by Alexander Morozov on 22.07.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//

import Foundation
import CryptoKit

class BackgroundCacheManager {
    static let shared = BackgroundCacheManager()

    // Soft limit for the video cache; least recently used files are evicted first
    private let maxCacheBytes = 300 * 1024 * 1024

    private init() {
        // One-time migration: earlier versions kept the cache in Documents/,
        // which is included in iCloud backups
        Task.detached(priority: .utility) {
            let legacyDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("backgroundVideos")
            try? FileManager.default.removeItem(at: legacyDir)
        }
    }

    func getLocalUrl(remoteUrl: URL) async throws -> URL {
        let localUrl = localVideoUrl(for: remoteUrl)
        let fm = FileManager.default

        if fm.fileExists(atPath: localUrl.path) {
            // Bump the date so eviction treats this file as recently used
            try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: localUrl.path)
            return localUrl
        }

        let (tempUrl, _) = try await URLSession.shared.download(from: remoteUrl)
        try? fm.moveItem(at: tempUrl, to: localUrl)

        trimCache()

        return localUrl
    }

    private func cacheDir() -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("backgroundVideos")

        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func localVideoUrl(for remoteUrl: URL) -> URL {
        var pathExt = remoteUrl.pathExtension
        if pathExt.isEmpty {
            pathExt = "mp4"
        }

        let inputData = Data(remoteUrl.absoluteString.utf8)
        let hash = SHA256.hash(data: inputData).map { String(format: "%02x", $0) }.joined()

        return cacheDir().appendingPathComponent("\(hash).\(pathExt)")
    }

    private func trimCache() {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .totalFileAllocatedSizeKey]

        guard let files = try? fm.contentsOfDirectory(at: cacheDir(), includingPropertiesForKeys: keys) else { return }

        var entries: [(url: URL, date: Date, size: Int)] = files.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return (url, values.contentModificationDate ?? .distantPast, values.totalFileAllocatedSize ?? 0)
        }

        var totalSize = entries.reduce(0) { $0 + $1.size }
        guard totalSize > maxCacheBytes else { return }

        entries.sort { $0.date < $1.date }
        for entry in entries {
            guard totalSize > maxCacheBytes else { break }
            try? fm.removeItem(at: entry.url)
            totalSize -= entry.size
        }
    }
}
