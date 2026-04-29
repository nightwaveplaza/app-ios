//
//  WebViewController.swift
//  NightwavePlaza
//
//  Created by Aleksey Garbarev on 02.08.2020.
//  Copyright © 2020 Aleksey Garbarev. All rights reserved.
//

import UIKit
@preconcurrency
import WebKit
import SafariServices
import Combine

class MainViewController: UIViewController, WKNavigationDelegate {
    
    let backgroundView = BackgroundView()
    lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(LocalSchemeHandler(), forURLScheme: "plaza")
        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }()
    
    private let playerService: PlayerService
    private let sleepTimerService: SleepTimerService
    private var startMenuHandler = StartMenuHandler()
    private var cancellables = Set<AnyCancellable>()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.playerService = PlayerService()
        self.sleepTimerService = SleepTimerService(playerService: playerService)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        self.playerService = PlayerService()
        self.sleepTimerService = SleepTimerService(playerService: playerService)
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(backgroundView)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        view.backgroundColor = UIColor(named: "BackgroundTeal")
        
        // register callbacks
        let webBridge = WebBridgeService(callback: self)
        webBridge.setup(configuration: webView.configuration, playerService: playerService, viewController: self)
        
        startMenuHandler.setup(inViewController: self) { [weak self] action in
            self?.handleMenuAction(action)
        }
        
        self.setupWebView()
        setupController()
    }
    
    private func setupController() {
        playerService.$isPlaying
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isPlaying in
            self?.pushPlaybackState(isPlaying: isPlaying)
        }
        .store(in: &cancellables)
    }
    
    private func pushPlaybackState(isPlaying: Bool) {
        print("Playback state: ", isPlaying)
        webView.emitEvent(action: "player:playing", payload: isPlaying)
    }
    
    
    func setupWebView() {
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
                
        if let url = URL(string: "plaza://localhost") {
            webView.load(URLRequest(url: url))
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var prefersStatusBarHidden: Bool {
        return Settings.fullScreen
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebViewError: Did Fail Navigation \(String(describing: navigation)), Error = \(error)");
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WebViewError: didFailProvisionalNavigation \(String(describing: navigation)), Error = \(error)");

    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        if url.scheme == "mailto" {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                let errorAlert = UIAlertController(title: "Error", message: "Unable to compose mail.", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "Ok", style: .default))
                self.present(errorAlert, animated: true)
            }
            decisionHandler(.cancel)
            return
        }
        
        if url.host == "plaza.int" {
            decisionHandler(.allow)
            return
        }
    
        if url.scheme?.hasPrefix("http") == true {
            let controller = SFSafariViewController(url: url)
            self.present(controller, animated: true, completion: nil)
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
    
    private func handleMenuAction(_ action: String) {
        print(action)
        webView.emitEvent(action: "window:open", payload: action)
    }
}

extension MainViewController: WebViewCallback {
    
    func onOpenDrawer() {
        startMenuHandler.show()
    }
    
    func onPlayAudio() {
        if (playerService.isPlaying) {
            playerService.pause()
        } else {
            playerService.play()
            webView.emitEvent(action: "player:buffering")
        }
    }
    
    func onSetBackground(src: String) {
        if src == "solid" {
            backgroundView.setSolid()
        } else if let url = URL(string: src) {
            backgroundView.setUrl(url: url)
        }
    }
    
    func onToggleFullscreen() {
        Settings.fullScreen = !Settings.fullScreen
        UIView.animate(withDuration: 0.5) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    func onSetSleepTimer(time: Double) {
        sleepTimerService.sleepAt(timestamp: time)
    }
    
    func onSetLanguage(lang: String) {
        //Settings.language = lang
    }
    
    func onReady() {
        print("Vue App is ready!")
        webView.emitEvent(action: "player:playing", payload: playerService.isPlaying)
    }
    
    func onSetThemeColor(color: String) {
        Settings.themeColor = color
    }
}
