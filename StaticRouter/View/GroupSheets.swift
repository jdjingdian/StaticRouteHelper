//
//  GroupSheets.swift
//  StaticRouteHelper
//

import SwiftUI
import SwiftData

// MARK: - AddGroupSheet

struct AddGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RouteGroup.sortOrder) private var groups: [RouteGroup]

    @State private var name = ""
    @State private var iconName = "folder"
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private let availableIcons = [
        ("folder", "文件夹"),
        ("network", "网络"),
        ("lock.shield", "安全"),
        ("house", "家"),
        ("building.2", "办公"),
        ("server.rack", "服务器"),
        ("cloud", "云"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("添加分组")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("分组名称")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("例如：Office VPN", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { if isValid { save() } }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("图标")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(availableIcons, id: \.0) { (icon, _) in
                        Button {
                            iconName = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 16))
                                .frame(width: 36, height: 36)
                                .background(iconName == icon ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("添加") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .frame(width: 280)
        .padding(20)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newGroup = RouteGroup(
            name: trimmed,
            iconName: iconName,
            sortOrder: groups.count
        )
        modelContext.insert(newGroup)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - AssignGroupsSheet

struct AssignGroupsSheet: View {
    let rule: RouteRule
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RouteGroup.sortOrder) private var allGroups: [RouteGroup]

    @State private var selectedGroupIDs: Set<PersistentIdentifier> = []

    init(rule: RouteRule) {
        self.rule = rule
        // selectedGroupIDs is populated in onAppear / task
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("管理分组")
                .font(.headline)

            if allGroups.isEmpty {
                Text("尚无分组，请先在侧栏创建分组")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                List(allGroups) { group in
                    Button {
                        if selectedGroupIDs.contains(group.persistentModelID) {
                            selectedGroupIDs.remove(group.persistentModelID)
                        } else {
                            selectedGroupIDs.insert(group.persistentModelID)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedGroupIDs.contains(group.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedGroupIDs.contains(group.persistentModelID) ? Color.accentColor : Color.secondary)
                            Image(systemName: group.iconName ?? "folder")
                                .foregroundStyle(.secondary)
                            Text(group.name)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
                .frame(minHeight: 120, maxHeight: 260)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 300)
        .task {
            // Pre-select current groups
            selectedGroupIDs = Set(rule.groups.map(\.persistentModelID))
        }
    }

    private func save() {
        // Clear existing associations from both sides
        for group in rule.groups {
            group.routes.removeAll { $0.persistentModelID == rule.persistentModelID }
        }
        rule.groups.removeAll()

        // Re-establish selected associations
        for group in allGroups where selectedGroupIDs.contains(group.persistentModelID) {
            rule.groups.append(group)
            if !group.routes.contains(where: { $0.persistentModelID == rule.persistentModelID }) {
                group.routes.append(rule)
            }
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - RenameGroupSheet

struct RenameGroupSheet: View {
    let group: RouteGroup
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name: String

    init(group: RouteGroup) {
        self.group = group
        _name = State(initialValue: group.name)
    }

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var hasChanged: Bool { name.trimmingCharacters(in: .whitespaces) != group.name }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("重命名分组")
                .font(.headline)

            TextField("分组名称", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { if isValid { save() } }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid || !hasChanged)
            }
        }
        .padding(20)
        .frame(width: 280)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        group.name = trimmed
        try? modelContext.save()
        dismiss()
    }
}
