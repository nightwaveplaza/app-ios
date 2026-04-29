//
//  String+Localized.swift
//  NightwavePlaza
//
//  Created by Alexander on 29.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//

extension String {
    var localized: String {
        return LanguageManager.getBundle().localizedString(forKey: self, value: nil, table: nil)
    }
}
