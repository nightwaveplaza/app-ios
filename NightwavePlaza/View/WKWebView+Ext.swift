//
//  WKWebView+Ext.swift
//  NightwavePlaza
//
//  Created by Alexander on 27.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//
import WebKit

extension WKWebView {
        
    func emitEvent<T: Encodable>(action: String, payload: T) {
        DispatchQueue.main.async {
            do {
                let data = try JSONEncoder().encode(payload)
                let json = String(data: data, encoding: .utf8) ?? "null"
                
                self.callAsyncJavaScript(
                    "window.dispatchEvent(new CustomEvent(action, { detail: JSON.parse(json) }))",
                    arguments: ["action": action, "json": json],
                    in: nil,
                    in: .page
                ) { result in
                    if case .failure(let error) = result {
                        print("JS Evaluation Error for \(action): \(error)")
                    }
                }
            } catch {
                print("JS Encode Error for \(action): \(error)")
            }
        }
    }
     
    func emitEvent(action: String) {
        DispatchQueue.main.async {
            self.callAsyncJavaScript(
                "window.dispatchEvent(new CustomEvent(action))",
                arguments: ["action": action],
                in: nil,
                in: .page
            )
        }
    }
}
