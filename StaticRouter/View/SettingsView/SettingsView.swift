//
//  SettingsView.swift
//  StaticRouteHelper
//

import Foundation
import SwiftUI

struct SettingsView: View {
    private enum SettingsTab: Hashable {
        case general
        case about
    }

    private struct ContentHeightPreferenceKey: PreferenceKey {
        static var defaultValue: [SettingsTab: CGFloat] = [:]

        static func reduce(value: inout [SettingsTab: CGFloat], nextValue: () -> [SettingsTab: CGFloat]) {
            value.merge(nextValue(), uniquingKeysWith: { $1 })
        }
    }

    private struct MeasuredTabContent<Content: View>: View {
        let tab: SettingsTab
        @ViewBuilder var content: Content

        var body: some View {
            content
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ContentHeightPreferenceKey.self,
                            value: [tab: proxy.size.height]
                        )
                    }
                )
        }
    }

    private let width: CGFloat = 620
    private let tabChromeHeight: CGFloat = 74
    @State private var selection: SettingsTab = .general
    @State private var contentHeights: [SettingsTab: CGFloat] = [:]

    var body: some View {
        TabView(selection: $selection) {
            MeasuredTabContent(tab: .general) {
                GeneralSettingsView()
            }
            .tabItem {
                Label(String(localized: "settings.tab.general"), systemImage: "gear")
            }
            .tag(SettingsTab.general)

            MeasuredTabContent(tab: .about) {
                AboutView()
            }
            .tabItem {
                Label(String(localized: "settings.tab.about"), systemImage: "questionmark.circle")
            }
            .tag(SettingsTab.about)
        }
        .tint(RouterTheme.accent)
        .frame(width: width, height: adaptiveHeight)
        .onPreferenceChange(ContentHeightPreferenceKey.self) { heights in
            contentHeights = heights
        }
        .animation(.easeInOut(duration: 0.2), value: adaptiveHeight)
    }

    private var adaptiveHeight: CGFloat {
        let defaultContentHeight: CGFloat = 230
        let contentHeight = contentHeights[selection] ?? defaultContentHeight
        return contentHeight + tabChromeHeight
    }
}
