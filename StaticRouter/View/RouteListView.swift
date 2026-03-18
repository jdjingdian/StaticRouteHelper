//
//  RouteListView.swift
//  StaticRouteHelper
//

import SwiftUI
import SwiftData

// MARK: - RouteListView

@available(macOS 14, *)
struct RouteListView: View {
    /// nil = All Routes mode; non-nil = filtered by group
    let group: RouteGroup?

    @EnvironmentObject private var routerService: RouterService
    @Environment(\.modelContext) private var modelContext

    // Fetch all routes; filtering by group happens in-view
    @Query(sort: \RouteRule.createdAt) private var allRoutes: [RouteRule]

    @State private var showAddSheet = false
    @State private var tableSelection: Set<UUID> = []
    @State private var routeToEdit: RouteRule? = nil
    @State private var routeToDelete: RouteRule? = nil
    @State private var routeToAssignGroups: RouteRule? = nil
    @State private var activationError: RouterError? = nil
    @State private var showActivationError = false

    // MARK: - Computed

    private var routes: [RouteRule] {
        if let group {
            return allRoutes.filter { $0.groups.contains { $0.id == group.id } }
        }
        return allRoutes
    }

    private var activeCount: Int { routes.filter(\.isActive).count }

    private var title: String {
        group?.name ?? String(localized: "route.list.all_routes.title")
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header stats bar
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(String(format: String(localized: "route.list.stats"), routes.count, activeCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help(String(localized: "route.list.add.tooltip"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if routes.isEmpty {
                emptyState
            } else {
                routeTable
            }
        }
        .sheet(isPresented: $showAddSheet) {
            RouteEditSheet(existingRule: nil, preselectedGroup: group)
        }
        .sheet(item: $routeToEdit) { rule in
            RouteEditSheet(existingRule: rule, preselectedGroup: nil)
        }
        .sheet(item: $routeToAssignGroups) { rule in
            AssignGroupsSheet(rule: rule)
        }
        .alert(
            String(localized: "route.list.alert.delete.title"),
            isPresented: Binding(
                get: { routeToDelete != nil },
                set: { if !$0 { routeToDelete = nil } }
            )
        ) {
            Button(String(localized: "route.list.alert.delete.confirm"), role: .destructive) {
                if let rule = routeToDelete { performDelete(rule) }
                routeToDelete = nil
            }
            Button(String(localized: "Cancel"), role: .cancel) { routeToDelete = nil }
        } message: {
            if routeToDelete?.isActive == true {
                Text(String(localized: "route.list.alert.delete.active_message"))
            } else {
                Text(String(localized: "route.list.alert.delete.message"))
            }
        }
        .alert(
            String(localized: "route.list.alert.activation_error.title"),
            isPresented: $showActivationError
        ) {
            Button(String(localized: "route.list.alert.activation_error.confirm"), role: .cancel) {}
        } message: {
            Text(activationError?.localizedDescription ?? String(localized: "route.list.alert.activation_error.unknown"))
        }
        .alert(
            String(localized: "route.list.recovery.alert.title"),
            isPresented: Binding(
                get: { routerService.smAppServiceRecoveryState != nil },
                set: { if !$0 { routerService.clearSMAppServiceRecoveryState() } }
            )
        ) {
            if routerService.smAppServiceRecoveryState?.canAutoReinstall == true {
                Button(String(localized: "route.list.recovery.alert.auto_reinstall")) {
                    performAutoReinstall()
                }
            }
            Button(String(localized: "route.list.recovery.alert.cancel"), role: .cancel) {
                routerService.clearSMAppServiceRecoveryState()
            }
        } message: {
            let fallback = String(localized: "route.list.recovery.alert.message")
            Text(routerService.smAppServiceRecoveryState?.errorMessage ?? fallback)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(String(localized: "route.list.empty.label"))
                .foregroundStyle(.secondary)
            Button(String(localized: "route.list.empty.add_button")) { showAddSheet = true }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    // MARK: - Route Table

    private var routeTable: some View {
        Table(routes, selection: $tableSelection) {
            TableColumn(String(localized: "route.list.column.destination")) { rule in
                Text(rule.cidrNotation)
                    .font(.system(.body, design: .monospaced))
            }
            TableColumn(String(localized: "route.list.column.gateway")) { rule in
                HStack(spacing: 4) {
                    Image(systemName: rule.gatewayType == .ipAddress ? "arrow.triangle.turn.up.right.circle" : "cable.connector")
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                    Text(rule.gateway)
                        .font(.system(.body, design: .monospaced))
                }
            }
            TableColumn(String(localized: "route.list.column.groups")) { rule in
                if rule.groups.isEmpty {
                    Text("—").foregroundStyle(.tertiary)
                } else {
                    Text(rule.groups.map(\.name).joined(separator: ", "))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            TableColumn(String(localized: "route.list.column.active")) { rule in
                RouteToggle(rule: rule, routerService: routerService) { error in
                    if routerService.smAppServiceRecoveryState == nil {
                        activationError = error
                        showActivationError = true
                    }
                }
                .disabled(routerService.helperStatus != .installed || routerService.isAutoReinstallInProgress)
            }
            .width(60)
            TableColumn(String(localized: "route.list.column.actions")) { rule in
                HStack(spacing: 6) {
                    Button {
                        routeToEdit = rule
                    } label: {
                        Image(systemName: "pencil")
                            .imageScale(.small)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .help(String(localized: "route.list.action.edit.tooltip"))

                    Button {
                        routeToAssignGroups = rule
                    } label: {
                        Image(systemName: "folder.badge.person.crop")
                            .imageScale(.small)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .help(String(localized: "route.list.action.assign_groups.tooltip"))

                    Button {
                        routeToDelete = rule
                    } label: {
                        Image(systemName: "trash")
                            .imageScale(.small)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .help(String(localized: "route.list.action.delete.tooltip"))
                }
            }
            .width(120)
        }
        .contextMenu(forSelectionType: UUID.self) { selectedIDs in
            if let id = selectedIDs.first, let rule = routes.first(where: { $0.id == id }) {
                Button(String(localized: "route.list.context.edit")) { routeToEdit = rule }
                Button(String(localized: "route.list.context.assign_groups")) { routeToAssignGroups = rule }
                Button(String(localized: "route.list.context.delete"), role: .destructive) { routeToDelete = rule }
                Divider()
                Button(String(localized: "route.list.context.copy")) { copyRouteInfo(rule) }
            }
        } primaryAction: { selectedIDs in
            if let id = selectedIDs.first, let rule = routes.first(where: { $0.id == id }) {
                routeToEdit = rule
            }
        }
    }

    // MARK: - Actions

    private func performDelete(_ rule: RouteRule) {
        Task {
            if rule.isActive {
                try? await routerService.deactivateRoute(rule)
                rule.isActive = false
            }
            for group in rule.groups {
                group.routes.removeAll { $0.id == rule.id }
            }
            modelContext.delete(rule)
            try? modelContext.save()
        }
    }

    private func copyRouteInfo(_ rule: RouteRule) {
        let info = "\(rule.cidrNotation) via \(rule.gateway)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
    }

    private func performAutoReinstall() {
        Task {
            do {
                try await routerService.autoReinstallSMAppServiceHelper()
                routerService.clearSMAppServiceRecoveryState()
            } catch let error as RouterError {
                activationError = error
                showActivationError = true
            } catch {
                let failurePrefix = String(localized: "route.list.recovery.alert.failure")
                activationError = .helperRecoveryFailed("\(failurePrefix) \(error.localizedDescription)")
                showActivationError = true
            }
        }
    }
}

// MARK: - RouteToggle

/// A toggle that activates/deactivates a route, with error rollback support.
@available(macOS 14, *)
struct RouteToggle: View {
    let rule: RouteRule
    let routerService: RouterService
    let onError: (RouterError) -> Void

    @State private var isLoading = false

    var body: some View {
        Toggle("", isOn: Binding(
            get: { rule.isActive },
            set: { newValue in
                Task { await toggle(to: newValue) }
            }
        ))
        .toggleStyle(.switch)
        .labelsHidden()
        .disabled(isLoading)
    }

    @MainActor
    private func toggle(to active: Bool) async {
        isLoading = true
        defer { isLoading = false }
        do {
            if active {
                try await routerService.activateRoute(rule)
                rule.isActive = true
            } else {
                try await routerService.deactivateRoute(rule)
                rule.isActive = false
            }
        } catch let error as RouterError {
            onError(error)
        } catch {
            onError(.xpcError(error.localizedDescription))
        }
    }
}
