//
//  LocalWebServer.swift
//  NightwavePlaza
//
//  Created by Alexander on 29.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//

import Foundation
import Swifter

class LocalWebServer {
    static let shared = LocalWebServer()
    
    private let server = HttpServer()
    
    private init() {}
    
    func start() {
        guard let publicDir = Bundle.main.path(forResource: "WebApp", ofType: nil) else {
            print("WebApp not found in bundle")
            return
        }
        
        server.middleware.append { [weak self] request in
            guard let self = self else { return nil }
            let path = request.path
            
            let relativePath = path == "/" ? "/index.html" : path
            let fullPath = publicDir + relativePath
            
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue {
                return self.serveFile(at: fullPath)
            }
            
            if relativePath.contains(".") {
                return .notFound
            }
            
            let indexHtml = publicDir + "/index.html"
            if FileManager.default.fileExists(atPath: indexHtml) {
                return self.serveFile(at: indexHtml)
            }
            
            return nil
        }

        do {
            try server.start(8080)
            print("Local server started on port 8080")
        } catch {
            print("Failed to run local server: \(error)")
        }
    }
    
    private func serveFile(at path: String) -> HttpResponse {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return .notFound
        }
        
        let ext = (path as NSString).pathExtension.lowercased()
        let mimeType: String
        
        switch ext {
        case "html": mimeType = "text/html"
        case "css": mimeType = "text/css"
        case "js", "mjs": mimeType = "application/javascript"
        case "json": mimeType = "application/json"
        case "png": mimeType = "image/png"
        case "jpg", "jpeg": mimeType = "image/jpeg"
        case "svg": mimeType = "image/svg+xml"
        case "woff", "woff2", "ttf", "eot": mimeType = "font/\(ext)"
        case "mp4": mimeType = "video/mp4"
        case "webm": mimeType = "video/webm"
        default: mimeType = "application/octet-stream"
        }
        
        return .raw(200, "OK", ["Content-Type": mimeType]) { writer in
            try? writer.write([UInt8](data))
        }
    }
}
