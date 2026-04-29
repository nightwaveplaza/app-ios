//
//  MainViewController.swift
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

class MainViewController: UIViewController {
    
    // MARK: - UI Components
    let backgroundView = BackgroundView()
    
    lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }()
    
    // MARK: - Dependencies & State
    private let playerService: PlayerService
    private let sleepTimerService: SleepTimerService
    private var startMenuHandler = StartMenuHandler()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    // Core application services are instantiated early to ensure playback
    // and background timer logic are ready before the visual layer mounts
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
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(backgroundView)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // Anchoring WebView directly to the view's edges (ignoring safe areas)
        // to allow the web app to draw edge-to-edge and handle notch insets via CSS
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
        
        // Binds JS postMessage events to native protocol execution
        let webBridge = WebBridgeService(callback: self)
        webBridge.setup(configuration: webView.configuration, playerService: playerService, viewController: self)
        
        startMenuHandler.setup(inViewController: self) { [weak self] action in
            self?.handleMenuAction(action)
        }
        
        self.setupWebView()
        setupController()
        
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidUpdate), name: .languageChanged, object: nil)
    }
    
    // MARK: - Setup & Configuration
    
    // Subscribes to the underlying audio engine's state changes
    // Forces UI-bound emissions to the main thread to prevent WebView execution crashes
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
        
        // Prevents the system from injecting automatic scroll padding,
        // leaving environmental inset control entirely to the web layer
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
        
        LocalWebServer.shared.start()
                
        if let url = URL(string: "http://localapp.plaza.one:8080") {
            webView.load(URLRequest(url: url))
        }
    }
    
    // MARK: - Status Bar Configuration
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return Settings.themeColor.isLightColor ? .darkContent : .lightContent
    }
    
    override var prefersStatusBarHidden: Bool {
        return Settings.fullScreen
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    // MARK: - Helpers
    private func handleMenuAction(_ action: String) {
        print(action)
        webView.emitEvent(action: "window:open", payload: action)
    }
    
    @objc private func languageDidUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.startMenuHandler.reloadLanguage()
        }
    }
}

// MARK: - WKNavigationDelegate
extension MainViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebViewError: Did Fail Navigation \(String(describing: navigation)), Error = \(error)");
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WebViewError: didFailProvisionalNavigation \(String(describing: navigation)), Error = \(error)");
    }
    
    // Sandboxes navigation to protect the core SPA environment
    // Routes external traffic to isolated system components
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        
        // Allow iframes
        if navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
            return
        }
        
        // Explicitly whitelist internal API communication
        if url.host == "plaza.int" || url.host == "localapp.plaza.one" {
            decisionHandler(.allow)
            return
        }
        
        // Route native mail links to the default system composer
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
    
        // Prevent hijacking the main WebView. Open external web links in a modal Safari browser
        if url.scheme?.hasPrefix("http") == true {
            let controller = SFSafariViewController(url: url)
            self.present(controller, animated: true, completion: nil)
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
}

// MARK: - WebViewCallback

// Routes abstracted interactions from the JS layer to native implementations.
extension MainViewController: WebViewCallback {
    
    func onOpenDrawer() {
        startMenuHandler.show()
    }
    
    func onPlayAudio() {
        if (playerService.isPlaying) {
            playerService.pause()
        } else {
            webView.emitEvent(action: "player:buffering")
            playerService.play()
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
        // Animate the status bar to synchronize with the web layer's visual transition
        UIView.animate(withDuration: 0.5) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    func onSetSleepTimer(time: Double) {
        sleepTimerService.sleepAt(timestamp: time)
    }
    
    func onSetLanguage(lang: String) {
        LanguageManager.setLanguage(lang)
    }
    
    func onReady() {
        print("Vue App is ready!")
        // Sync the web layer with the actual playback state upon initialization
        webView.emitEvent(action: "player:playing", payload: playerService.isPlaying)
    }
    
    func onSetThemeColor(color: String) {
        Settings.themeColor = color
        
        UIView.animate(withDuration: 0.3) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
}
