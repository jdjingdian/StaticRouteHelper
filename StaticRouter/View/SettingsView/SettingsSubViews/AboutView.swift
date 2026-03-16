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
                    Text("Help you manage macOS network routes.")
                        .font(.title3)
                    PaddedDivider(padding: nil)
                    Text("Version: \(appVersion)")
                        .font(.caption.italic())
                }
            }
            PaddedDivider(padding: nil)
            HStack {
                VStack(alignment: .leading) {
                    Text("StaticRouteHelper is licensed under the GPLv3 license.")
                    Text("Copyright © 2021, [Derek Jing](https://github.com/jdjingdian)")
                }
                Spacer()
                Button {
                    visitHomepage()
                } label: {
                    HStack {
                        Image(systemName: "house")
                        Text("Project Home Page")
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
