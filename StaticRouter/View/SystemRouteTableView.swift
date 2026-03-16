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
    @AppStorage("systemRouteTable.showOnlyMyRoutes") private var showOnlyMyRoutes: Bool = false
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

    private func isUserRoute(_ entry: SystemRouteEntry) -> Bool {
        let normalizedDest = normalizeIPv4Destination(entry.destination)
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

    private var displayedRoutes: [SystemRouteEntry] {
        showOnlyMyRoutes ? myRoutes : filteredRoutes
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with search + refresh
            HStack {
                Text(String(localized: "system.route.title"))
                    .font(.headline)
                Spacer()
                TextField(String(localized: "system.route.search.placeholder"), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Toggle(isOn: $showOnlyMyRoutes) {
                    Label(String(localized: "system.route.filter.my_routes"), systemImage: "person.fill")
                }
                .toggleStyle(.button)
                .help(String(localized: "system.route.filter.my_routes.tooltip"))
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
                .help(String(localized: "system.route.refresh.tooltip"))
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
                                    .foregroundStyle(Color.accentColor)
                                    .imageScale(.small)
                            }
                            Text(entry.destination)
                                .font(.system(.body, design: .monospaced))
                        }
                        .padding(.vertical, 1)
                        .background(isUserRoute(entry) ? Color.accentColor.opacity(0.08) : Color.clear)
                    }
                    TableColumn(String(localized: "system.route.column.gateway")) { entry in
                        Text(entry.gateway)
                            .font(.system(.body, design: .monospaced))
                            .background(isUserRoute(entry) ? Color.accentColor.opacity(0.08) : Color.clear)
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
