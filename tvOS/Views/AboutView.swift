//
//  AboutView.swift
//  NightwavePlaza tvOS
//

import SwiftUI
import UIKit

struct AboutView: View {
    private let appName: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Nightwave Plaza"
    }()

    private let appVersion: String = {
        let marketingVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return "\(marketingVersion) (\(build))"
    }()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon
            if let icon = UIImage(named: "AppIcon") {
                Button(action: {}) {
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(1.0, contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 36))
                }
                .buttonStyle(.plain)
            }

            // App name
            Text(appName)
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)

            // Version
            Text("Version \(appVersion)")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.white.opacity(0.6))

            // Credits
            Text("Built by the Nightwave Plaza community")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 8)

            // Website
            HStack(spacing: 8) {
                Image(systemName: "globe")
                Text("plaza.one")
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.05, green: 0.15, blue: 0.15))
    }

    private func openWebsite() {
        if let url = URL(string: "https://plaza.one") {
            UIApplication.shared.open(url)
        }
    }
}

#if DEBUG
#Preview("About") {
    PreviewContainer {
        AboutView()
    }
}
#endif
