//
//  WebViewController.swift
//  NightwavePlaza
//
//  Created by Aleksey Garbarev on 02.08.2020.
//  Copyright © 2020 Aleksey Garbarev. All rights reserved.
//

import Foundation
import WebKit
import RxCocoa
import RxSwift
import SafariServices

class WebViewController: UIViewController, WKNavigationDelegate {
    
    let backgroundView = BackgroundView()
    let webView = WKWebView()
    
    private var disposeBag = DisposeBag()
    
    private let playback: PlaybackService

    
    private let webBridge = WebBridgeService()
    
    private var selectionWasDisabled = false
    
    var fullScreenStorage = CCUserDefaultsStorage(with: NSNumber.self, key: "fullScreen")
    var fullScreen: Bool {
        set {
            
            fullScreenStorage?.save(NSNumber(booleanLiteral: newValue))
        }
        get {
            if let value = fullScreenStorage?.getObject() as? NSNumber {
                return value.boolValue
            } else {
                return true
            }
        }
    }
    
    var timer: Timer?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.playback = PlaybackService();
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        self.playback = PlaybackService();
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        
        self.view.addSubview(backgroundView)
        backgroundView.autoPinEdgesToSuperviewEdges()
        
        self.webBridge.setup(webView: self.webView, statusService: self.statusService, playback: self.playback, metadata: self.metadata, viewController: self);
        
        self.setupWebView()
    }
    
    
    func setupWebView() {
        self.view.addSubview(webView);
        webView.autoPinEdgesToSuperviewEdges()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        
//        var resourcesPath: NSString
//        
//        #if targetEnvironment(macCatalyst)
//        resourcesPath = Bundle.main.resourcePath! as NSString
//        #else
//        resourcesPath = Bundle.main.bundlePath as NSString
//        #endif
//
//        let webPath = resourcesPath.appendingPathComponent("web");
//        let indexPath = (webPath as NSString).appendingPathComponent("index.html");
//        
//        let indexContent = try! NSString(contentsOfFile: indexPath, encoding: String.Encoding.utf8.rawValue);
// 
//        webView.loadHTMLString(indexContent as String, baseURL: URL(fileURLWithPath: webPath));
//        webView.navigationDelegate = self
        
        guard let url = URL(string: "http://plaza.local:4173") else {
                print("Invalid URL")
                return
            }
        let request = URLRequest(url: url)
            webView.load(request)
            
            webView.navigationDelegate = self
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var prefersStatusBarHidden: Bool {
        return self.fullScreen
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
        
        if let url = navigationAction.request.url, url.scheme == "mailto" {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                let error = UIAlertController(title: "Error", message: "Unable to compose mail. Please check mail configuration and try again", preferredStyle: .alert);
                error.addAction(UIAlertAction(title: "Ok", style: .default, handler: { [unowned error] (_action) in
                    error.dismiss(animated: true, completion: nil)
                }))
                self.present(error, animated: true, completion: nil)
            }
            decisionHandler(.cancel)
        } else if let url = navigationAction.request.url, url.scheme?.hasPrefix("http") == true {
            let controller = SFSafariViewController(url: url)
            self.present(controller, animated: true, completion: nil)
            
            decisionHandler(.cancel)
        }
        else {
            decisionHandler(.allow)
        }

    }


    
}

