//
//  String+Color.swift
//  NightwavePlaza
//
//  Created by Alexander on 29.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//

import UIKit // UIKit нужен, так как мы используем CGFloat

extension String {
    var isLightColor: Bool {
        var hexSanitized = self.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return false }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        let luminance = (r * 0.299) + (g * 0.587) + (b * 0.114)
        return luminance > 0.6
    }
}
