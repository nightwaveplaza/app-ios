//
//  AppPreference.swift
//  NightwavePlaza
//
//  Created by Alexander on 25.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//

import Foundation

@propertyWrapper
struct AppPreference<T> {
    let key: String
    let defaultValue: T

    var wrappedValue: T {
        get {
            return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}
