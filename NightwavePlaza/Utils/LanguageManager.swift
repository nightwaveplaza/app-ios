//
//  LanguageManager.swift
//  NightwavePlaza
//
//  Created by Alexander on 29.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//
import Foundation

enum LanguageManager {
    private static let userDefaultsKey = "selected_language"

    static func setLanguage(_ code: String) {
        print("Set language: \(code)")
        Settings.language = code
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }

    static func getBundle() -> Bundle {
        let code = Settings.language
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

extension Notification.Name {
    static let languageChanged = Notification.Name("AppLanguageChanged")
}
