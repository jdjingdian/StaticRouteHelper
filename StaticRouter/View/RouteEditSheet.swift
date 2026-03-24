//
//  RouteEditSheet.swift
//  StaticRouteHelper
//

import SwiftUI
import SwiftData

@available(macOS 14, *)
struct RouteEditSheet: View {
    /// nil = adding new route; non-nil = editing existing route
    let existingRule: RouteRule?
    /// Pre-selected group (when adding from a group view)
    let preselectedGroup: RouteGroup?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var routerService: RouterService

    @Query(sort: \RouteGroup.sortOrder) private var allGroups: [RouteGroup]

    // MARK: - Form State

    @State private var network: String = ""
    @State private var prefixLength: Int = 24
    @State private var gatewayType: GatewayType = .ipAddress
    @State private var gateway: String = ""
    @State private var selectedGroupIDs: Set<UUID> = []

    // MARK: - Validation State

    @State private var networkError: String? = nil
    @State private var gatewayError: String? = nil

    private var prefixLengthError: String? {
        RouteValidator.isValidPrefixLength(prefixLength) ? nil : String(localized: "route.edit.field.prefix_error")
    }

    private var isFormValid: Bool {
        networkError == nil && gatewayError == nil && prefixLengthError == nil
            && !network.isEmpty && !gateway.isEmpty
    }

    private var isEditing: Bool { existingRule != nil }
    private var wasActive: Bool { existingRule?.isActive ?? false }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? String(localized: "route.edit.title.edit") : String(localized: "route.edit.title.add"))
                    .font(.title2.bold())
                Text("CIDR / Gateway / Group")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Network Address + Prefix Length
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "route.edit.field.destination.label"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("192.168.4.0", text: $network)
                        .textFieldStyle(.roundedBorder)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(networkError != nil ? RouterTheme.danger : Color.clear, lineWidth: 1)
                        )
                        .onChange(of: network) { _, _ in validateNetwork() }

                    Text("/")
                        .foregroundStyle(.secondary)

                    TextField("24", value: $prefixLength, format: .number)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 68)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(prefixLengthError != nil ? RouterTheme.danger : Color.clear, lineWidth: 1)
                        )
                }

                Text("= \(subnetMaskPreview)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let err = networkError {
                    Text(err).font(.caption).foregroundStyle(RouterTheme.danger)
                }
                if let err = prefixLengthError {
                    Text(err).font(.caption).foregroundStyle(RouterTheme.danger)
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(RouterTheme.subtleBorder, lineWidth: 0.6)
            )

            // Gateway Type Picker + Gateway Input
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "route.edit.field.gateway.label"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker(String(localized: "route.edit.field.gateway.label"), selection: $gatewayType) {
                    Text(String(localized: "route.edit.gateway.ip_option")).tag(GatewayType.ipAddress)
                    Text(String(localized: "route.edit.gateway.interface_option")).tag(GatewayType.interface)
                }
                .pickerStyle(.segmented)
                .onChange(of: gatewayType) { _, _ in gateway = ""; validateGateway() }

                TextField(gatewayType == .ipAddress ? "10.0.0.1" : "utun3", text: $gateway)
                    .textFieldStyle(.roundedBorder)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(gatewayError != nil ? RouterTheme.danger : Color.clear, lineWidth: 1)
                    )
                    .onChange(of: gateway) { _, _ in validateGateway() }

                if let err = gatewayError {
                    Text(err).font(.caption).foregroundStyle(RouterTheme.danger)
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(RouterTheme.subtleBorder, lineWidth: 0.6)
            )

            // Group Multi-Select
            if !allGroups.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "route.edit.field.groups.label"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                        ForEach(allGroups) { group in
                            let isSelected = selectedGroupIDs.contains(group.id)
                            Button {
                                toggleGroupSelection(group.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    Image(systemName: group.iconName ?? "folder")
                                    Text(group.name)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .font(.callout)
                                .foregroundStyle(isSelected ? RouterTheme.accent : Color.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(isSelected ? RouterTheme.accentSoft : RouterTheme.subtleFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(isSelected ? RouterTheme.accent.opacity(0.35) : RouterTheme.subtleBorder, lineWidth: 0.6)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(RouterTheme.subtleBorder, lineWidth: 0.6)
                )
            }

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "route.edit.button.cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.bordered)
                Button(isEditing ? String(localized: "route.edit.button.save") : String(localized: "route.edit.button.add")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear { populateFromExisting() }
    }

    // MARK: - Computed

    private var subnetMaskPreview: String {
        guard prefixLength >= 0, prefixLength <= 32 else { return String(localized: "route.edit.mask_preview.invalid") }
        let mask: UInt32 = prefixLength == 0 ? 0 : (~UInt32(0) << (32 - prefixLength))
        return "\((mask>>24)&0xFF).\((mask>>16)&0xFF).\((mask>>8)&0xFF).\(mask&0xFF)"
    }

    // MARK: - Validation

    private func validateNetwork() {
        let trimmed = network.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { networkError = nil; return }
        networkError = RouteValidator.isValidIPv4(trimmed) ? nil : String(localized: "route.edit.field.network_error")
    }

    private func validateGateway() {
        let trimmed = gateway.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { gatewayError = nil; return }
        if gatewayType == .ipAddress {
            gatewayError = RouteValidator.isValidIPv4(trimmed) ? nil : String(localized: "route.edit.gateway.ip_error")
        } else {
            gatewayError = RouteValidator.isValidGatewayOrInterface(trimmed) ? nil : String(localized: "route.edit.gateway.interface_error")
        }
    }

    private func toggleGroupSelection(_ id: UUID) {
        if selectedGroupIDs.contains(id) {
            selectedGroupIDs.remove(id)
        } else {
            selectedGroupIDs.insert(id)
        }
    }

    // MARK: - Pre-populate

    private func populateFromExisting() {
        if let rule = existingRule {
            network = rule.network
            prefixLength = rule.prefixLength
            gatewayType = rule.gatewayType
            gateway = rule.gateway
            selectedGroupIDs = Set(rule.groups.map(\.id))
        } else if let preselectedGroup {
            selectedGroupIDs = [preselectedGroup.id]
        }
    }

    // MARK: - Save

    private func save() {
        let trimmedNetwork = network.trimmingCharacters(in: .whitespaces)
        let trimmedGateway = gateway.trimmingCharacters(in: .whitespaces)

        let selectedGroups = allGroups.filter { selectedGroupIDs.contains($0.id) }

        if let rule = existingRule {
            // Editing existing route
            let networkChanged = rule.network != trimmedNetwork
                || rule.prefixLength != prefixLength
                || rule.gateway != trimmedGateway
                || rule.gatewayType != gatewayType

            rule.network = trimmedNetwork
            rule.prefixLength = prefixLength
            rule.gatewayType = gatewayType
            rule.gateway = trimmedGateway

            // Update group associations
            // Remove from old groups not in new selection
            for oldGroup in rule.groups where !selectedGroupIDs.contains(oldGroup.id) {
                oldGroup.routes.removeAll { $0.id == rule.id }
            }
            // Add to new groups
            for newGroup in selectedGroups where !rule.groups.contains(where: { $0.id == newGroup.id }) {
                newGroup.routes.append(rule)
            }
            rule.groups = selectedGroups

            try? modelContext.save()

            // Re-activate if route was active and network config changed (task 6.4)
            if wasActive && networkChanged {
                Task {
                    // Deactivate old, then activate new
                    try? await routerService.deactivateRoute(rule)
                    try? await routerService.activateRoute(rule)
                }
            }
        } else {
            // Adding new route
            let rule = RouteRule(
                network: trimmedNetwork,
                prefixLength: prefixLength,
                gatewayType: gatewayType,
                gateway: trimmedGateway,
                isActive: false,
                groups: selectedGroups
            )
            modelContext.insert(rule)
            for group in selectedGroups {
                group.routes.append(rule)
            }
            try? modelContext.save()
        }

        dismiss()
    }
}
