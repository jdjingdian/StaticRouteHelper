//
//  RouteListView.swift
//  StaticRouteHelper
//

import SwiftUI
import SwiftData

// MARK: - RouteListView

struct RouteListView: View {
    /// nil = All Routes mode; non-nil = filtered by group
    let group: RouteGroup?

    @Environment(RouterService.self) private var routerService
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
        group?.name ?? "所有路由"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header stats bar
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(routes.count) 条路由 · \(activeCount) 条已激活")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("添加路由")
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
            "删除路由？",
            isPresented: Binding(
                get: { routeToDelete != nil },
                set: { if !$0 { routeToDelete = nil } }
            )
        ) {
            Button("删除", role: .destructive) {
                if let rule = routeToDelete { performDelete(rule) }
                routeToDelete = nil
            }
            Button("取消", role: .cancel) { routeToDelete = nil }
        } message: {
            if routeToDelete?.isActive == true {
                Text("该路由当前处于激活状态，删除前将自动停用。")
            } else {
                Text("此操作无法撤销。")
            }
        }
        .alert(
            "激活失败",
            isPresented: $showActivationError
        ) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(activationError?.localizedDescription ?? "未知错误")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("暂无路由")
                .foregroundStyle(.secondary)
            Button("添加路由") { showAddSheet = true }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    // MARK: - Route Table

    private var routeTable: some View {
        Table(routes, selection: $tableSelection) {
            TableColumn("目标网络 / CIDR") { rule in
                Text(rule.cidrNotation)
                    .font(.system(.body, design: .monospaced))
            }
            TableColumn("网关 / 接口") { rule in
                HStack(spacing: 4) {
                    Image(systemName: rule.gatewayType == .ipAddress ? "arrow.triangle.turn.up.right.circle" : "cable.connector")
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                    Text(rule.gateway)
                        .font(.system(.body, design: .monospaced))
                }
            }
            TableColumn("分组") { rule in
                if rule.groups.isEmpty {
                    Text("—").foregroundStyle(.tertiary)
                } else {
                    Text(rule.groups.map(\.name).joined(separator: ", "))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            TableColumn("激活") { rule in
                RouteToggle(rule: rule, routerService: routerService) { error in
                    activationError = error
                    showActivationError = true
                }
                .disabled(routerService.helperStatus != .installed)
            }
            .width(60)
            TableColumn("操作") { rule in
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
                    .help("编辑")

                    Button {
                        routeToAssignGroups = rule
                    } label: {
                        Image(systemName: "folder.badge.person.crop")
                            .imageScale(.small)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .help("管理分组")

                    Button {
                        routeToDelete = rule
                    } label: {
                        Image(systemName: "trash")
                            .imageScale(.small)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .help("删除")
                }
            }
            .width(120)
        }
        .contextMenu(forSelectionType: UUID.self) { selectedIDs in
            if let id = selectedIDs.first, let rule = routes.first(where: { $0.id == id }) {
                Button("编辑") { routeToEdit = rule }
                Button("管理分组…") { routeToAssignGroups = rule }
                Button("删除", role: .destructive) { routeToDelete = rule }
                Divider()
                Button("复制路由信息") { copyRouteInfo(rule) }
            }
        } primaryAction: { selectedIDs in
            // Double-click = edit
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
            // Detach from all groups
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
}

// MARK: - RouteToggle

/// A toggle that activates/deactivates a route, with error rollback support.
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
            // Rollback — isActive is not changed, so UI naturally reverts
            onError(error)
        } catch {
            onError(.xpcError(error.localizedDescription))
        }
    }
}
