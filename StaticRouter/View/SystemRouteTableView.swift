//
//  SystemRouteTableView.swift
//  StaticRouteHelper
//

import SwiftUI
import SwiftData

struct SystemRouteTableView: View {
    @EnvironmentObject private var routerService: RouterService

    var body: some View {
        if #available(macOS 14, *) {
            SystemRouteTableView14()
        } else {
            LegacySystemRouteTableView()
        }
    }
}

// MARK: - macOS 14+ System Route Table

@available(macOS 14, *)
private struct SystemRouteTableView14: View {
    @EnvironmentObject private var routerService: RouterService
    @Query private var userRoutes: [RouteRule]

    @State private var searchText = ""
    @AppStorage("systemRouteTable.showOnlyMyRoutes") private var showOnlyMyRoutes: Bool = false
    @State private var lastRefreshTime: Date? = nil
    @State private var isRefreshing = false
    @State private var errorMessage: String? = nil

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

    private func isUserRoute(_ entry: SystemRouteEntry) -> Bool {
        let normalizedDest = normalizeIPv4Destination(entry.destination)
        return userRoutes.contains { rule in
            rule.network == normalizedDest && rule.gateway == entry.gateway
        }
    }

    private var myRoutes: [SystemRouteEntry] { filteredRoutes.filter { isUserRoute($0) } }
    private var displayedRoutes: [SystemRouteEntry] { showOnlyMyRoutes ? myRoutes : filteredRoutes }

    var body: some View {
        SystemRouteTableContent(
            routerService: routerService,
            searchText: $searchText,
            showOnlyMyRoutes: $showOnlyMyRoutes,
            lastRefreshTime: $lastRefreshTime,
            isRefreshing: $isRefreshing,
            errorMessage: $errorMessage,
            filteredRoutes: filteredRoutes,
            displayedRoutes: displayedRoutes,
            myRoutes: myRoutes,
            isUserRoute: isUserRoute
        )
    }
}

// MARK: - Legacy System Route Table (macOS 12–13)

private struct LegacySystemRouteTableView: View {
    @EnvironmentObject private var routerService: RouterService
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RouteRuleMO.createdAt, ascending: true)]
    ) private var userRoutesMO: FetchedResults<RouteRuleMO>

    @State private var searchText = ""
    @AppStorage("systemRouteTable.showOnlyMyRoutes") private var showOnlyMyRoutes: Bool = false
    @State private var lastRefreshTime: Date? = nil
    @State private var isRefreshing = false
    @State private var errorMessage: String? = nil

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

    private func isUserRoute(_ entry: SystemRouteEntry) -> Bool {
        let normalizedDest = normalizeIPv4Destination(entry.destination)
        return userRoutesMO.contains { mo in
            mo.network == normalizedDest && mo.gateway == entry.gateway
        }
    }

    private var myRoutes: [SystemRouteEntry] { filteredRoutes.filter { isUserRoute($0) } }
    private var displayedRoutes: [SystemRouteEntry] { showOnlyMyRoutes ? myRoutes : filteredRoutes }

    var body: some View {
        SystemRouteTableContent(
            routerService: routerService,
            searchText: $searchText,
            showOnlyMyRoutes: $showOnlyMyRoutes,
            lastRefreshTime: $lastRefreshTime,
            isRefreshing: $isRefreshing,
            errorMessage: $errorMessage,
            filteredRoutes: filteredRoutes,
            displayedRoutes: displayedRoutes,
            myRoutes: myRoutes,
            isUserRoute: isUserRoute
        )
    }
}

// MARK: - Shared Content View

private struct SystemRouteTableContent: View {
    let routerService: RouterService
    @Binding var searchText: String
    @Binding var showOnlyMyRoutes: Bool
    @Binding var lastRefreshTime: Date?
    @Binding var isRefreshing: Bool
    @Binding var errorMessage: String?
    let filteredRoutes: [SystemRouteEntry]
    let displayedRoutes: [SystemRouteEntry]
    let myRoutes: [SystemRouteEntry]
    let isUserRoute: (SystemRouteEntry) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header with search + refresh
            HStack {
                Text(String(localized: "system.route.title"))
                    .font(.title3.weight(.semibold))
                Spacer()
                TextField(String(localized: "system.route.search.placeholder"), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.regular)
                    .frame(width: 260)
                Toggle(isOn: $showOnlyMyRoutes) {
                    Label(String(localized: "system.route.filter.my_routes"), systemImage: "person.fill")
                }
                .toggleStyle(.button)
                .controlSize(.regular)
                .help(String(localized: "system.route.filter.my_routes.tooltip"))
                Button {
                    refresh()
                } label: {
                    if isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 24, height: 20)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isRefreshing || routerService.helperStatus != .installed)
                .help(String(localized: "system.route.refresh.tooltip"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if routerService.helperStatus != .installed {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(RouterTheme.warning)
                    Text(String(localized: "system.route.helper_required"))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if routerService.systemRoutes.isEmpty && !isRefreshing {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text(String(localized: "system.route.empty.label"))
                        .foregroundStyle(.secondary)
                    Button(String(localized: "system.route.empty.load_button")) { refresh() }
                        .buttonStyle(.borderedProminent)
                }
                Spacer()
            } else {
                routeTable
            }

            // Status bar
            Divider()
            HStack {
                if showOnlyMyRoutes {
                    if let time = lastRefreshTime {
                        Text(String(format: String(localized: "system.route.status.my_routes_with_time"), myRoutes.count, routerService.systemRoutes.count, time.formatted(date: .omitted, time: .shortened)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(format: String(localized: "system.route.status.my_routes"), myRoutes.count, routerService.systemRoutes.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    if let time = lastRefreshTime {
                        Text(String(format: String(localized: "system.route.status.all_with_time"), routerService.systemRoutes.count, time.formatted(date: .omitted, time: .shortened)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(format: String(localized: "system.route.status.all"), routerService.systemRoutes.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(RouterTheme.danger)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RouterTheme.subtleFill)
        }
        .task {
            if routerService.systemRoutes.isEmpty && routerService.helperStatus == .installed {
                await performRefresh()
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showOnlyMyRoutes)
    }

    // MARK: - Route Table

    private var routeTable: some View {
        Group {
            if displayedRoutes.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    if showOnlyMyRoutes && searchText.isEmpty {
                        Text(String(localized: "system.route.my_routes.empty.label"))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(localized: "system.route.search.no_results"))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            } else {
                Table(displayedRoutes) {
                    TableColumn(String(localized: "system.route.column.destination")) { entry in
                        HStack(spacing: 4) {
                            if isUserRoute(entry) {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(RouterTheme.accent)
                                    .imageScale(.small)
                            }
                            Text(entry.destination)
                                .font(.system(.body, design: .monospaced))
                        }
                        .padding(.vertical, 1)
                    }
                    TableColumn(String(localized: "system.route.column.gateway")) { entry in
                        Text(entry.gateway)
                            .font(.system(.body, design: .monospaced))
                    }
                    TableColumn(String(localized: "system.route.column.flags")) { entry in
                        Text(entry.flags)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .width(80)
                    TableColumn(String(localized: "system.route.column.interface")) { entry in
                        Text(entry.networkInterface)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(70)
                    TableColumn(String(localized: "system.route.column.expire")) { entry in
                        Text(entry.expire.isEmpty ? "—" : entry.expire)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .width(60)
                }
            }
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
        await routerService.refreshSystemRoutes()
        lastRefreshTime = Date()
    }
}
