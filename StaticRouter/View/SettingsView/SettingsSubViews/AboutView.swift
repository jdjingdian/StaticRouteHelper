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
        VStack(alignment: .leading) {
            HStack {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imgLength, height: imgLength)
                VStack(alignment: .leading) {
                    Text("Static Route Helper")
                        .font(.largeTitle.bold())
                    Text(String(localized: "about.app.subtitle"))
                        .font(.title3)
                    PaddedDivider(padding: nil)
                    Text(String(format: String(localized: "about.version"), appVersion))
                        .font(.caption.italic())
                }
            }
            PaddedDivider(padding: nil)
            HStack {
                VStack(alignment: .leading) {
                    Text(String(localized: "about.license"))
                    Text(String(localized: "about.copyright"))
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
                .buttonStyle(DefaultButtonStyle(type: .buttonNeutral(.thin)))
            }
        }
        .padding()
    }

    private func visitHomepage() {
        guard let url = URL(string: "https://github.com/jdjingdian/StaticRouteHelper") else { return }
        NSWorkspace.shared.open(url)
    }
}
