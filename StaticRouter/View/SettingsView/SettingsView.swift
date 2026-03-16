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
                Label("General", systemImage: "gear")
            }
            AboutView().tabItem {
                Label("About", systemImage: "questionmark.circle")
            }
        }
        .frame(width: width)
    }
}
