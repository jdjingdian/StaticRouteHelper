//
//  SidebarView.swift
//  StaticRouteHelper
//

import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @Query(sort: \RouteGroup.sortOrder) private var groups: [RouteGroup]
    @Query private var allRoutes: [RouteRule]
    @State private var showAddGroupSheet = false

    @State private var groupToRename: RouteGroup? = nil
    @State private var groupToDelete: RouteGroup? = nil

    var body: some View {
        List(selection: $selection) {
            // MARK: All Routes
            Label("所有路由", systemImage: "list.bullet")
                .badge(allRoutes.count)
                .tag(SidebarItem.allRoutes)

            // MARK: Groups Section
            if !groups.isEmpty {
                Section("分组") {
                    ForEach(groups) { group in
                        Label(group.name, systemImage: group.iconName ?? "folder")
                            .badge(group.routes.count)
                            .tag(SidebarItem.group(group))
                            .contextMenu {
                                Button("重命名") { groupToRename = group }
                                Divider()
                                Button("删除", role: .destructive) { groupToDelete = group }
                            }
                    }
                    .onMove { from, to in
                        moveGroups(from: from, to: to)
                    }
                }
            }

            // MARK: System Section
            Section("系统") {
                Label("路由表", systemImage: "network")
                    .tag(SidebarItem.systemRoutes)
            }
        }
        .navigationTitle("Static Route Helper")
        .safeAreaInset(edge: .bottom) {
            bottomToolbar
        }
        .sheet(isPresented: $showAddGroupSheet) {
            AddGroupSheet()
        }
        .sheet(item: $groupToRename) { group in
            RenameGroupSheet(group: group)
        }
        .alert(
            "删除分组「\(groupToDelete?.name ?? "")」？",
            isPresented: Binding(get: { groupToDelete != nil }, set: { if !$0 { groupToDelete = nil } })
        ) {
            Button("删除", role: .destructive) {
                if let group = groupToDelete { deleteGroup(group) }
                groupToDelete = nil
            }
            Button("取消", role: .cancel) { groupToDelete = nil }
        } message: {
            Text("分组内的路由不会被删除，仅解除关联。")
        }
    }

    private func deleteGroup(_ group: RouteGroup) {
        for route in group.routes {
            route.groups.removeAll { $0.id == group.id }
        }
        modelContext.delete(group)
        try? modelContext.save()
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack {
            Button {
                showAddGroupSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .help("添加分组")

            Spacer()

            SettingsLink {
                Image(systemName: "gear")
            }
            .buttonStyle(.plain)
            .help("设置")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Group Reorder

    @Environment(\.modelContext) private var modelContext

    private func moveGroups(from source: IndexSet, to destination: Int) {
        var reordered = groups
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, group) in reordered.enumerated() {
            group.sortOrder = index
        }
        try? modelContext.save()
    }
}

// MARK: - Group Context Menu

/// Context menu buttons for a sidebar group row.
/// The actual sheet/alert presentation happens on the row in SidebarView.
struct GroupContextMenu: View {
    let group: RouteGroup
    @Binding var showRenameSheet: Bool
    @Binding var showDeleteAlert: Bool

    var body: some View {
        Button("重命名") {
            showRenameSheet = true
        }
        Divider()
        Button("删除", role: .destructive) {
            showDeleteAlert = true
        }
    }
}
