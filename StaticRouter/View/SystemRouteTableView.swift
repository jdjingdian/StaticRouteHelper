//
//  SystemRouteTableView.swift
//  StaticRouteHelper
//

import SwiftUI
import SwiftData

struct SystemRouteTableView: View {
    @Environment(RouterService.self) private var routerService
    @Query private var userRoutes: [RouteRule]

    @State private var searchText = ""
    @State private var lastRefreshTime: Date? = nil
    @State private var isRefreshing = false
    @State private var errorMessage: String? = nil

    // MARK: - Computed

    private var filteredRoutes: [SystemRouteEntry] {
        let routes = routerService.systemRoutes
        if searchText.isEmpty { return routes }
        let lower = searchText.lowercased()
        return routes.filter {
            $0.destination.lowercased().contains(lower)
            || $0.gateway.lowercased().contains(lower)
            || $0.networkInterface.lowercased().contains(lower)
        }
    }

    /// 将 netstat 输出的目标地址规范化为完整 IPv4 表示。
    /// netstat 对网段地址会省略末尾连续的 ".0"，如 "192.168.3" → "192.168.3.0"，
    /// "10.0" → "10.0.0.0"。此处补齐到 4 段以便与 RouteRule.network 比较。
    private func normalizeDestination(_ destination: String) -> String {
        let parts = destination.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count < 4 else { return destination }
        let missing = 4 - parts.count
        return destination + String(repeating: ".0", count: missing)
    }

    private func isUserRoute(_ entry: SystemRouteEntry) -> Bool {
        let normalizedDest = normalizeDestination(entry.destination)
        return userRoutes.contains { rule in
            rule.network == normalizedDest
            && rule.gateway == entry.gateway
        }
    }

    private var myRoutes: [SystemRouteEntry] {
        filteredRoutes.filter { isUserRoute($0) }
    }

    private var systemOnlyRoutes: [SystemRouteEntry] {
        filteredRoutes.filter { !isUserRoute($0) }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with search + refresh
            HStack {
                Text("系统路由表")
                    .font(.headline)
                Spacer()
                TextField("搜索", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Button {
                    refresh()
                } label: {
                    if isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing || routerService.helperStatus != .installed)
                .help("刷新路由表")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if routerService.helperStatus != .installed {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.yellow)
                    Text("需要安装 Helper 才能查看系统路由表")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if routerService.systemRoutes.isEmpty && !isRefreshing {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("路由表为空")
                        .foregroundStyle(.secondary)
                    Button("加载路由表") { refresh() }
                        .buttonStyle(.borderedProminent)
                }
                Spacer()
            } else {
                routeTable
            }

            // Status bar
            Divider()
            HStack {
                if let time = lastRefreshTime {
                    Text("共 \(routerService.systemRoutes.count) 条路由 · 最后刷新：\(time, style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("共 \(routerService.systemRoutes.count) 条路由")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .task {
            // Auto-load on first appear if empty
            if routerService.systemRoutes.isEmpty && routerService.helperStatus == .installed {
                await performRefresh()
            }
        }
    }

    // MARK: - Route Table

    private var routeTable: some View {
        Table(filteredRoutes) {
            TableColumn("目标") { entry in
                HStack(spacing: 4) {
                    if isUserRoute(entry) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color.accentColor)
                            .imageScale(.small)
                    }
                    Text(entry.destination)
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.vertical, 1)
                .background(isUserRoute(entry) ? Color.accentColor.opacity(0.08) : Color.clear)
            }
            TableColumn("网关") { entry in
                Text(entry.gateway)
                    .font(.system(.body, design: .monospaced))
                    .background(isUserRoute(entry) ? Color.accentColor.opacity(0.08) : Color.clear)
            }
            TableColumn("标志") { entry in
                Text(entry.flags)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(80)
            TableColumn("接口") { entry in
                Text(entry.networkInterface)
                    .font(.system(.body, design: .monospaced))
            }
            .width(70)
            TableColumn("过期") { entry in
                Text(entry.expire.isEmpty ? "—" : entry.expire)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(60)
        }
    }

    // MARK: - Refresh

    private func refresh() {
        Task { await performRefresh() }
    }

    @MainActor
    private func performRefresh() async {
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }
        do {
            try await routerService.refreshSystemRoutes()
            lastRefreshTime = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
