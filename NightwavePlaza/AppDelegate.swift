//
//  AppDelegate.swift
//  NightwavePlaza
//
//  Created by Aleksey Garbarev on 24.05.2020.
//  Copyright © 2020 Aleksey Garbarev. All rights reserved.
//

import UIKit
import Sentry

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String, !dsn.isEmpty else {
            print("⚠️ SENTRY_DSN not found. Sentry disabled.")
            return true
        }
        
        SentrySDK.start { options in
            options.dsn = dsn
            options.tracesSampleRate = 0.1
        }
        
        return true
    }
}

