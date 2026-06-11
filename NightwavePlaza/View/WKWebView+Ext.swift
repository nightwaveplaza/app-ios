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
            let jsonString: String
            
            do {
                let data = try JSONEncoder().encode(payload)
                jsonString = String(data: data, encoding: .utf8) ?? "null"
            } catch {
                print("JS Encode Error for \(action): \(error)")
                jsonString = "null"
            }
                        
            let script = "window.dispatchEvent(new CustomEvent('\(action)', { detail: \(jsonString) }));"
            print(script)

            
            self.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("JS Evaluation Error: \(error)")
                }
            }
        }
    }
    
    func emitEvent(action: String) {
        DispatchQueue.main.async {
            let script = "window.dispatchEvent(new CustomEvent('\(action)'));"
            self.evaluateJavaScript(script)
        }
    }
}
