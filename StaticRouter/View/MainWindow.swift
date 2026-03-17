//
//  MainWindow.swift
//  StaticRouteHelper
//

import SwiftUI

// MARK: - Sidebar Selection (macOS 14+)

@available(macOS 14, *)
enum SidebarItem: Hashable {
    case allRoutes
    case group(RouteGroup)
    case systemRoutes
}

// MARK: - Legacy Sidebar Selection (macOS 12–13)

enum LegacySidebarItem: Hashable {
    case allRoutes
    case systemRoutes
}

// MARK: - MainWindow

struct MainWindow: View {
    @EnvironmentObject private var routerService: RouterService

    var body: some View {
        if #available(macOS 14, *) {
            MainWindow14()
        } else {
            LegacyMainWindow()
        }
    }
}

// MARK: - macOS 14+ Main Window

@available(macOS 14, *)
struct MainWindow14: View {
    @EnvironmentObject private var routerService: RouterService
    @State private var selection: SidebarItem? = .allRoutes

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            detail(for: selection)
                .frame(minWidth: 400)
        }
        .frame(minWidth: 600, minHeight: 420)
    }

    @ViewBuilder
    private func detail(for item: SidebarItem?) -> some View {
        VStack(spacing: 0) {
            if routerService.helperStatus != .installed {
                HelperNotInstalledBanner()
            }
            switch item {
            case .allRoutes, .none:
                RouteListView(group: nil)
            case .group(let group):
                RouteListView(group: group)
            case .systemRoutes:
                SystemRouteTableView()
            }
        }
    }
}

// MARK: - Legacy Main Window (macOS 12–13)

struct LegacyMainWindow: View {
    @EnvironmentObject private var routerService: RouterService
    @State private var selection: LegacySidebarItem? = .allRoutes

    var body: some View {
        NavigationView {
            LegacySidebarView(selection: $selection)
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)
            legacyDetail(for: selection)
                .frame(minWidth: 400)
        }
        .frame(minWidth: 600, minHeight: 420)
    }

    @ViewBuilder
    private func legacyDetail(for item: LegacySidebarItem?) -> some View {
        VStack(spacing: 0) {
            if routerService.helperStatus != .installed {
                HelperNotInstalledBanner()
            }
            switch item {
            case .allRoutes, .none:
                LegacyRouteListView()
            case .systemRoutes:
                SystemRouteTableView()
            }
        }
    }
}

// MARK: - Legacy Sidebar View (macOS 12–13)

struct LegacySidebarView: View {
    @Binding var selection: LegacySidebarItem?

    var body: some View {
        List(selection: $selection) {
            Label(String(localized: "sidebar.all_routes"), systemImage: "list.bullet")
                .tag(LegacySidebarItem.allRoutes)

            Section(String(localized: "sidebar.section.system")) {
                Label(String(localized: "sidebar.system.route_table"), systemImage: "network")
                    .tag(LegacySidebarItem.systemRoutes)
            }
        }
        .navigationTitle("Static Route Helper")
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
                .help(String(localized: "sidebar.toolbar.settings.tooltip"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}

// MARK: - HelperNotInstalledBanner

struct HelperNotInstalledBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(String(localized: "helper.banner.message"))
                .font(.callout)
            Spacer()
            if #available(macOS 14, *) {
                SettingsLink {
                    Text(String(localized: "helper.banner.goto_settings"))
                        .font(.callout)
                }
            } else {
                Button(String(localized: "helper.banner.goto_settings")) {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
                .font(.callout)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.yellow.opacity(0.12))
        Divider()
    }
}
