//
//  WebViewController.swift
//  NightwavePlaza
//
//  Created by Aleksey Garbarev on 02.08.2020.
//  Copyright © 2020 Aleksey Garbarev. All rights reserved.
//

import UIKit
import WebKit
import SafariServices

class WebViewController: UIViewController, WKNavigationDelegate {
    
    let backgroundView = BackgroundView()
    lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }()
    
    private let playback: PlaybackService
    private var selectionWasDisabled = false
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.playback = PlaybackService();
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        self.playback = PlaybackService();
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
        
        // register callbacks
        let webBridge = WebBridgeService(callback: self)
        webBridge.setup(configuration: webView.configuration, playback: playback, viewController: self)
        
        self.setupWebView()
    }
    
    
    func setupWebView() {
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
                
        guard let url = URL(string: "http://plaza.int:4173") else { return }
        webView.load(URLRequest(url: url))
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
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        if selectionWasDisabled == false {
            let javascriptStyle =
            """
                var css = 'input[type=text],input[type=password], input[type=email], input[type=number], input[type=time], input[type=date], textarea {-webkit-touch-callout: auto;-webkit-user-select: auto;} *{-webkit-touch-callout:none;-webkit-user-select:none}';
                var head = document.head || document.getElementsByTagName('head')[0]; var style = document.createElement('style'); style.type = 'text/css'; style.appendChild(document.createTextNode(css)); head.appendChild(style);
            """
            webView.evaluateJavaScript(javascriptStyle, completionHandler: nil)
            selectionWasDisabled = true
        }
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
}

extension WebViewController: WebViewCallback {
    
    func onOpenDrawer() {
   
    }
    
    func onPlayAudio() {
        playback.play()
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
    
    func onSetSleepTimer(time: Int) {
//        sleepTimer.sleepAfter(minutes: Double(time))
    }
    
    func onSetLanguage(lang: String) {
        //Settings.language = lang
    }
    
    func onReady() {
        print("Vue App is ready!")
    }
    
    func onSetThemeColor(color: String) {
        Settings.themeColor = color
    }
}
