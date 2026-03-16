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
            Label(String(localized: "sidebar.all_routes"), systemImage: "list.bullet")
                .badge(allRoutes.count)
                .tag(SidebarItem.allRoutes)

            // MARK: Groups Section
            if !groups.isEmpty {
                Section(String(localized: "sidebar.section.groups")) {
                    ForEach(groups) { group in
                        Label(group.name, systemImage: group.iconName ?? "folder")
                            .badge(group.routes.count)
                            .tag(SidebarItem.group(group))
                            .contextMenu {
                                Button(String(localized: "sidebar.group.context.rename")) { groupToRename = group }
                                Divider()
                                Button(String(localized: "sidebar.group.context.delete"), role: .destructive) { groupToDelete = group }
                            }
                    }
                    .onMove { from, to in
                        moveGroups(from: from, to: to)
                    }
                }
            }

            // MARK: System Section
            Section(String(localized: "sidebar.section.system")) {
                Label(String(localized: "sidebar.system.route_table"), systemImage: "network")
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
            String(localized: "sidebar.group.alert.delete.title").replacing("%@", with: groupToDelete?.name ?? ""),
            isPresented: Binding(get: { groupToDelete != nil }, set: { if !$0 { groupToDelete = nil } })
        ) {
            Button(String(localized: "sidebar.group.alert.delete.confirm"), role: .destructive) {
                if let group = groupToDelete { deleteGroup(group) }
                groupToDelete = nil
            }
            Button(String(localized: "sidebar.group.alert.delete.cancel"), role: .cancel) { groupToDelete = nil }
        } message: {
            Text(String(localized: "sidebar.group.alert.delete.message"))
        }
    }

    private func deleteGroup(_ group: RouteGroup) {
        let isCurrentlySelected: Bool
        if case .group(let selected) = selection {
            isCurrentlySelected = selected.id == group.id
        } else {
            isCurrentlySelected = false
        }

        for route in group.routes {
            route.groups.removeAll { $0.id == group.id }
        }
        modelContext.delete(group)
        try? modelContext.save()

        if isCurrentlySelected {
            selection = .allRoutes
        }
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
            .help(String(localized: "sidebar.toolbar.add_group.tooltip"))

            Spacer()

            SettingsLink {
                Image(systemName: "gear")
            }
            .buttonStyle(.plain)
            .help(String(localized: "sidebar.toolbar.settings.tooltip"))
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
struct GroupContextMenu: View {
    let group: RouteGroup
    @Binding var showRenameSheet: Bool
    @Binding var showDeleteAlert: Bool

    var body: some View {
        Button(String(localized: "sidebar.group.context.rename")) {
            showRenameSheet = true
        }
        Divider()
        Button(String(localized: "sidebar.group.context.delete"), role: .destructive) {
            showDeleteAlert = true
        }
    }
}
