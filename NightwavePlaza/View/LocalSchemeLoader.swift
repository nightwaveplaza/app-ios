//
//  LocalSchemeLoader.swift
//  NightwavePlaza
//
//  Created by Alexander on 28.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//

import WebKit
import MobileCoreServices

class LocalSchemeHandler: NSObject, WKURLSchemeHandler {
    
    private var activeTasks = Set<ObjectIdentifier>()
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let taskId = ObjectIdentifier(urlSchemeTask)
        activeTasks.insert(taskId)
        
        guard let url = urlSchemeTask.request.url else { return }
            
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var path = url.path
            if path.isEmpty || path == "/" {
                path = "/index.html"
            }
            
            let bundleUrl = Bundle.main.bundleURL
                .appendingPathComponent("WebApp")
                .appendingPathComponent(path)
            
            let data = try? Data(contentsOf: bundleUrl)
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                guard self.activeTasks.contains(taskId) else { return }
                
                if let data = data {
                    let finalExtension = bundleUrl.pathExtension
                    
                    let response = HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: "HTTP/1.1",
                        headerFields: [
                            "Content-Type": self.mimeType(for: finalExtension),
                            "Access-Control-Allow-Origin": "*"
                        ]
                    )!
                    
                    urlSchemeTask.didReceive(response)
                    urlSchemeTask.didReceive(data)
                    urlSchemeTask.didFinish()
                } else {
                    let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!
                    urlSchemeTask.didReceive(response)
                    urlSchemeTask.didFinish()
                }
                
                self.activeTasks.remove(taskId)
            }
        }
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
 
        let taskId = ObjectIdentifier(urlSchemeTask)
        activeTasks.remove(taskId)
    }
    
    private func mimeType(for extension: String) -> String {
        switch `extension`.lowercased() {
        case "html": return "text/html"
        case "css": return "text/css"
        case "js", "mjs": return "application/javascript"
        case "json": return "application/json"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "woff", "woff2", "eot", "ttf": return "font/\(`extension`.lowercased())"
        default: return "application/octet-stream"
        }
    }
}
