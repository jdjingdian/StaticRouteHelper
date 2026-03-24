//
//  LegacyRouteListView.swift
//  StaticRouteHelper
//
//  Route list view for macOS 12–13 (Core Data / Legacy persistence path).
//  Driven by @FetchRequest instead of @Query.
//

import SwiftUI
import CoreData

struct LegacyRouteListView: View {
    @EnvironmentObject private var routerService: RouterService
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RouteRuleMO.createdAt, ascending: true)],
        animation: .default
    )
    private var routes: FetchedResults<RouteRuleMO>

    @State private var showAddSheet = false
    @State private var routeToEdit: RouteRuleMO? = nil
    @State private var routeToDelete: RouteRuleMO? = nil
    @State private var activationError: RouterError? = nil
    @State private var showActivationError = false

    private var activeCount: Int { routes.filter(\.isActive).count }

    var body: some View {
        VStack(spacing: 0) {
            // Header stats bar
            HStack {
                Text(String(localized: "route.list.all_routes.title"))
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(String(format: String(localized: "route.list.stats"), routes.count, activeCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(RouterTheme.subtleFill, in: Capsule())
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 26, height: 22)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help(String(localized: "route.list.add.tooltip"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if routes.isEmpty {
                emptyState
            } else {
                routeTable
            }
        }
        .sheet(isPresented: $showAddSheet) {
            LegacyRouteEditSheet(existingMO: nil)
        }
        .sheet(item: $routeToEdit) { mo in
            LegacyRouteEditSheet(existingMO: mo)
        }
        .alert(
            String(localized: "route.list.alert.delete.title"),
            isPresented: Binding(
                get: { routeToDelete != nil },
                set: { if !$0 { routeToDelete = nil } }
            )
        ) {
            Button(String(localized: "route.list.alert.delete.confirm"), role: .destructive) {
                if let mo = routeToDelete { performDelete(mo) }
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
        Table(Array(routes)) {
            TableColumn(String(localized: "route.list.column.destination")) { mo in
                Text(mo.cidrNotation)
                    .font(.system(.body, design: .monospaced))
            }
            TableColumn(String(localized: "route.list.column.gateway")) { mo in
                HStack(spacing: 4) {
                    Image(systemName: mo.gatewayType == "ipAddress" ? "arrow.triangle.turn.up.right.circle" : "cable.connector")
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                    Text(mo.gateway)
                        .font(.system(.body, design: .monospaced))
                }
            }
            TableColumn(String(localized: "route.list.column.active")) { mo in
                LegacyRouteToggle(mo: mo, routerService: routerService, context: viewContext) { error in
                    if routerService.smAppServiceRecoveryState == nil {
                        activationError = error
                        showActivationError = true
                    }
                }
                .disabled(routerService.helperStatus != .installed || routerService.isAutoReinstallInProgress)
            }
            .width(60)
            TableColumn(String(localized: "route.list.column.actions")) { mo in
                HStack(spacing: 6) {
                    Button {
                        routeToEdit = mo
                    } label: {
                        Image(systemName: "pencil")
                            .imageScale(.small)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(LegacyRouteActionIconButtonStyle(tint: RouterTheme.accent))
                    .help(String(localized: "route.list.action.edit.tooltip"))

                    Button {
                        routeToDelete = mo
                    } label: {
                        Image(systemName: "trash")
                            .imageScale(.small)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(LegacyRouteActionIconButtonStyle(tint: RouterTheme.danger))
                    .help(String(localized: "route.list.action.delete.tooltip"))
                }
            }
            .width(90)
        }
    }

    // MARK: - Actions

    private func performDelete(_ mo: RouteRuleMO) {
        Task {
            if mo.isActive {
                try? await routerService.deactivateRouteMO(mo, context: viewContext)
            }
            await MainActor.run {
                viewContext.delete(mo)
                try? viewContext.save()
            }
        }
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

private struct LegacyRouteActionIconButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? tint.opacity(0.95) : tint)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(configuration.isPressed ? tint.opacity(0.22) : tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(tint.opacity(0.26), lineWidth: 0.6)
            )
            .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
    }
}

// MARK: - LegacyRouteToggle

struct LegacyRouteToggle: View {
    let mo: RouteRuleMO
    let routerService: RouterService
    let context: NSManagedObjectContext
    let onError: (RouterError) -> Void

    @State private var isLoading = false

    var body: some View {
        Toggle("", isOn: Binding(
            get: { mo.isActive },
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
                try await routerService.activateRouteMO(mo, context: context)
            } else {
                try await routerService.deactivateRouteMO(mo, context: context)
            }
        } catch let error as RouterError {
            onError(error)
        } catch {
            onError(.xpcError(error.localizedDescription))
        }
    }
}

// MARK: - LegacyRouteEditSheet

/// Lightweight edit sheet for macOS 12–13 (no group support)
struct LegacyRouteEditSheet: View {
    let existingMO: RouteRuleMO?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var routerService: RouterService

    @State private var network: String = ""
    @State private var prefixLength: Int = 24
    @State private var gatewayTypeStr: String = "ipAddress"
    @State private var gateway: String = ""

    @State private var networkError: String? = nil
    @State private var gatewayError: String? = nil

    private var isEditing: Bool { existingMO != nil }

    private var prefixLengthError: String? {
        RouteValidator.isValidPrefixLength(prefixLength) ? nil : String(localized: "route.edit.field.prefix_error")
    }

    private var isFormValid: Bool {
        networkError == nil && gatewayError == nil && prefixLengthError == nil
            && !network.isEmpty && !gateway.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(isEditing ? String(localized: "route.edit.title.edit") : String(localized: "route.edit.title.add"))
                .font(.headline)

            // Network + Prefix
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
                        .onChange(of: network) { _ in validateNetwork() }

                    Text("/").foregroundStyle(.secondary)

                    TextField("24", value: $prefixLength, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(prefixLengthError != nil ? Color.red : Color.clear, lineWidth: 1)
                        )
                }
                if let err = networkError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }

            // Gateway Type + Gateway
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "route.edit.field.gateway.label"))
                    .font(.subheadline).foregroundStyle(.secondary)
                Picker(String(localized: "route.edit.field.gateway.label"), selection: $gatewayTypeStr) {
                    Text(String(localized: "route.edit.gateway.ip_option")).tag("ipAddress")
                    Text(String(localized: "route.edit.gateway.interface_option")).tag("interface")
                }
                .pickerStyle(.radioGroup)
                .onChange(of: gatewayTypeStr) { _ in gateway = ""; validateGateway() }

                TextField(gatewayTypeStr == "ipAddress" ? "10.0.0.1" : "utun3", text: $gateway)
                    .textFieldStyle(.roundedBorder)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(gatewayError != nil ? Color.red : Color.clear, lineWidth: 1)
                    )
                    .onChange(of: gateway) { _ in validateGateway() }

                if let err = gatewayError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }

            Divider()

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
        .frame(width: 360)
        .onAppear { populate() }
    }

    private func populate() {
        guard let mo = existingMO else { return }
        network = mo.network
        prefixLength = Int(mo.prefixLength)
        gatewayTypeStr = mo.gatewayType
        gateway = mo.gateway
    }

    private func validateNetwork() {
        let t = network.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { networkError = nil; return }
        networkError = RouteValidator.isValidIPv4(t) ? nil : String(localized: "route.edit.field.network_error")
    }

    private func validateGateway() {
        let t = gateway.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { gatewayError = nil; return }
        if gatewayTypeStr == "ipAddress" {
            gatewayError = RouteValidator.isValidIPv4(t) ? nil : String(localized: "route.edit.gateway.ip_error")
        } else {
            gatewayError = RouteValidator.isValidGatewayOrInterface(t) ? nil : String(localized: "route.edit.gateway.interface_error")
        }
    }

    private func save() {
        let trimNetwork = network.trimmingCharacters(in: .whitespaces)
        let trimGateway = gateway.trimmingCharacters(in: .whitespaces)

        if let mo = existingMO {
            let networkChanged = mo.network != trimNetwork
                || mo.prefixLength != Int16(prefixLength)
                || mo.gateway != trimGateway
                || mo.gatewayType != gatewayTypeStr

            let wasActive = mo.isActive
            mo.network = trimNetwork
            mo.prefixLength = Int16(prefixLength)
            mo.gatewayType = gatewayTypeStr
            mo.gateway = trimGateway
            try? viewContext.save()

            if wasActive && networkChanged {
                Task {
                    try? await routerService.deactivateRouteMO(mo, context: viewContext)
                    try? await routerService.activateRouteMO(mo, context: viewContext)
                }
            }
        } else {
            RouteRuleMO.create(
                in: viewContext,
                network: trimNetwork,
                prefixLength: Int16(prefixLength),
                gatewayType: gatewayTypeStr,
                gateway: trimGateway
            )
            try? viewContext.save()
        }

        dismiss()
    }
}
