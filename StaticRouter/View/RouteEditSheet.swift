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
        VStack(alignment: .leading, spacing: 20) {
            Text(isEditing ? String(localized: "route.edit.title.edit") : String(localized: "route.edit.title.add"))
                .font(.headline)

            // Network Address + Prefix Length
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "route.edit.field.destination.label"))
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("192.168.4.0", text: $network)
                        .textFieldStyle(.roundedBorder)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(networkError != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                        .onChange(of: network) { _, _ in validateNetwork() }

                    Text("/")
                        .foregroundStyle(.secondary)

                    TextField("24", value: $prefixLength, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(prefixLengthError != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                        .onChange(of: prefixLength) { _, _ in validateGateway() }
                }

                // Subnet mask preview
                Text("= \(subnetMaskPreview)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let err = networkError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }

            // Gateway Type Picker + Gateway Input
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "route.edit.field.gateway.label"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Picker(String(localized: "route.edit.field.gateway.label"), selection: $gatewayType) {
                    Text(String(localized: "route.edit.gateway.ip_option")).tag(GatewayType.ipAddress)
                    Text(String(localized: "route.edit.gateway.interface_option")).tag(GatewayType.interface)
                }
                .pickerStyle(.radioGroup)
                .onChange(of: gatewayType) { _, _ in gateway = ""; validateGateway() }

                TextField(gatewayType == .ipAddress ? "10.0.0.1" : "utun3", text: $gateway)
                    .textFieldStyle(.roundedBorder)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(gatewayError != nil ? Color.red : Color.clear, lineWidth: 1)
                    )
                    .onChange(of: gateway) { _, _ in validateGateway() }

                if let err = gatewayError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }

            // Group Multi-Select
            if !allGroups.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "route.edit.field.groups.label"))
                        .font(.subheadline).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(allGroups) { group in
                            Toggle(group.name, isOn: Binding(
                                get: { selectedGroupIDs.contains(group.id) },
                                set: { checked in
                                    if checked { selectedGroupIDs.insert(group.id) }
                                    else { selectedGroupIDs.remove(group.id) }
                                }
                            ))
                        }
                    }
                }
            }

            Divider()

            // Buttons
            HStack {
                Spacer()
                Button(String(localized: "route.edit.button.cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? String(localized: "route.edit.button.save") : String(localized: "route.edit.button.add")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isFormValid)
            }
        }
        .padding(24)
        .frame(width: 380)
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
