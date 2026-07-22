//
//  WebBridgeService.swift
//  NightwavePlaza
//
//  Created by Aleksey Garbarev on 16.08.2020.
//  Copyright © 2020 Aleksey Garbarev. All rights reserved.
//

import Foundation
@preconcurrency import WebKit

class WebBridgeService: NSObject, WKScriptMessageHandlerWithReply {
    weak var viewController: MainViewController?
    private var playerService: PlayerService!
    private var sleepTimer: SleepTimerService!
    
    weak var callback: WebViewCallback?
        
    init(callback: WebViewCallback) {
        self.callback = callback
        super.init()
    }
    
    func setup(
        configuration: WKWebViewConfiguration,
        playerService: PlayerService,
        viewController: MainViewController
    ) {
        self.playerService = playerService        
        self.viewController = viewController
        
        configuration.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "ios_app")
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        
        guard let body = message.body as? [String: Any], let method = body["method"] as? String else {
            replyHandler(nil, "Invalid message format")
            return
        }
        
        let args = body["args"] as? [Any] ?? []
        
        print(method)
        
        switch method {                
            case "playAudio":
                callback?.onPlayAudio()
                replyHandler(nil, nil)
            
            case "stopAudio":
                callback?.onStopAudio()
                replyHandler(nil, nil)
                
            case "setBackground":
                if let src = args.first as? String {
                    callback?.onSetBackground(src: src)
                }
                replyHandler(nil, nil)
                
            case "toggleFullscreen":
                callback?.onToggleFullscreen()
                replyHandler(nil, nil)
                
            case "getUserAgent":
                // TODO
                replyHandler("NightwavePlaza iOS App", nil)
                
            case "setAudioQuality":
                if let lowQuality = args.first as? Bool {
                    Settings.lowQualityAudio = lowQuality
                }
                replyHandler(nil, nil)
                
            case "setSleepTimer":
                if let time = args.first as? Double {
                    callback?.onSetSleepTimer(time: time)
                }
                replyHandler(nil, nil)
                
            case "getAuthToken":
                replyHandler(Settings.userToken, nil)
                
            case "setAuthToken":
                if let token = args.first as? String {
                    Settings.userToken = token
                }
                replyHandler(nil, nil)
                
            case "getAppVersion":
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                replyHandler("\(version) (build \(build))", nil)
                
            case "setLanguage":
                if let lang = args.first as? String {
                    callback?.onSetLanguage(lang: lang)
                }
                replyHandler(nil, nil)
                
            case "onReady":
                callback?.onReady()
                replyHandler(nil, nil)
                
            case "setThemeColor":
                if let color = args.first as? String {
                    callback?.onSetThemeColor(color: color)
                }
                replyHandler(nil, nil)
                
            default:
                print("Unhandled JS method: \(method)")
                replyHandler(nil, "Method not implemented")
        }
    }
}
