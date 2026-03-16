//
//  SettingsView.swift
//  StaticRouteHelper
//

import Foundation
import SwiftUI

struct SettingsView: View {
    private let width: CGFloat = 540

    var body: some View {
        TabView {
            GeneralSettingsView().tabItem {
                Label(String(localized: "settings.tab.general"), systemImage: "gear")
            }
            AboutView().tabItem {
                Label(String(localized: "settings.tab.about"), systemImage: "questionmark.circle")
            }
        }
        .frame(width: width)
    }
}
