//
//  MainWindow.swift
//  StaticRouteHelper
//

import SwiftUI
import SwiftData

// MARK: - Sidebar Selection

enum SidebarItem: Hashable {
    case allRoutes
    case group(RouteGroup)
    case systemRoutes
}

// MARK: - MainWindow

struct MainWindow: View {
    @Environment(RouterService.self) private var routerService
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
            // Helper 未安装时显示横幅
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

// MARK: - HelperNotInstalledBanner

struct HelperNotInstalledBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Helper 工具未安装，路由操作不可用。请前往设置安装。")
                .font(.callout)
            Spacer()
            SettingsLink {
                Text("前往设置")
                    .font(.callout)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.yellow.opacity(0.12))
        Divider()
    }
}
