//
//  AboutView.swift
//  StaticRouteHelper
//

import Foundation
import SwiftUI

struct AboutView: View {
    private let imgLength: CGFloat = 128
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imgLength, height: imgLength)
                VStack(alignment: .leading) {
                    Text("Static Route Helper")
                        .font(.largeTitle.bold())
                    Text(String(localized: "about.app.subtitle"))
                        .font(.title3.weight(.medium))
                    PaddedDivider(padding: nil)
                    Text(String(format: String(localized: "about.version"), appVersion))
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RouterTheme.subtleFill, in: Capsule())
                }
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(RouterTheme.subtleBorder, lineWidth: 0.6)
            )

            HStack {
                VStack(alignment: .leading) {
                    Text(String(localized: "about.license"))
                    Text(String(localized: "about.copyright"))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    visitHomepage()
                } label: {
                    HStack {
                        Image(systemName: "house")
                        Text(String(localized: "about.homepage.button"))
                            .font(.footnote)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(RouterTheme.subtleBorder, lineWidth: 0.6)
            )
        }
        .padding(20)
    }

    private func visitHomepage() {
        guard let url = URL(string: "https://github.com/jdjingdian/StaticRouteHelper") else { return }
        NSWorkspace.shared.open(url)
    }
}
