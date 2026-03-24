//
//  InstallMethodChooserSheet.swift
//  StaticRouteHelper
//
//  Sheet presented on macOS 14+ when the user taps "Install".
//  Lets the user choose between SMAppService (recommended) and SMJobBless.
//

import SwiftUI
import ServiceManagement

@available(macOS 13, *)
struct InstallMethodChooserSheet: View {

    // MARK: - Bindings / Callbacks

    /// Reflects @AppStorage("preferredInstallMethod") from the parent.
    @Binding var preferredMethodRaw: String

    let onInstall: (InstallMethod) -> Void
    let onCancel: () -> Void

    // MARK: - Local State

    @State private var selectedMethod: InstallMethod = .smAppService

    // MARK: - Init

    init(
        preferredMethodRaw: Binding<String>,
        onInstall: @escaping (InstallMethod) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._preferredMethodRaw = preferredMethodRaw
        self.onInstall = onInstall
        self.onCancel = onCancel
        // Pre-select from stored preference
        let stored = InstallMethod(rawStorage: preferredMethodRaw.wrappedValue) ?? .smAppService
        self._selectedMethod = State(initialValue: stored)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Title
            Text(String(localized: "chooser.title"))
                .font(.title2.bold())

            Text(String(localized: "chooser.subtitle"))
                .font(.body)
                .foregroundStyle(.secondary)

            // Method options
            VStack(spacing: 0) {
                methodRow(
                    method: .smAppService,
                    title: String(localized: "chooser.method.smappservice.title"),
                    description: String(localized: "chooser.method.smappservice.description"),
                    isRecommended: true
                )
                Divider()
                methodRow(
                    method: .smJobBless,
                    title: String(localized: "chooser.method.smjobbless.title"),
                    description: String(localized: "chooser.method.smjobbless.description"),
                    isRecommended: false
                )
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(RouterTheme.subtleBorder, lineWidth: 1)
            )

            // Buttons
            HStack {
                Spacer()
                Button(String(localized: "chooser.button.cancel")) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button(String(localized: "chooser.button.install")) {
                    onInstall(selectedMethod)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(RouterTheme.accent)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    // MARK: - Method Row

    @ViewBuilder
    private func methodRow(
        method: InstallMethod,
        title: String,
        description: String,
        isRecommended: Bool
    ) -> some View {
        Button {
            selectedMethod = method
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Radio indicator
                Image(systemName: selectedMethod == method
                      ? "largecircle.fill.circle"
                      : "circle")
                    .foregroundStyle(selectedMethod == method ? RouterTheme.accent : Color.secondary)
                    .font(.title3)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.body.weight(.medium))
                        if isRecommended {
                            Text(String(localized: "chooser.recommended_badge"))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(RouterTheme.accentSoft)
                                .foregroundStyle(RouterTheme.accent)
                                .clipShape(Capsule())
                        }
                    }
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(selectedMethod == method ? RouterTheme.accentSoft : Color.clear)
    }
}

// MARK: - InstallMethod rawStorage helpers

extension InstallMethod {
    /// UserDefaults-friendly raw string value.
    var rawStorageValue: String {
        switch self {
        case .smAppService: return "smAppService"
        case .smJobBless:   return "smJobBless"
        }
    }

    /// Reconstructs from UserDefaults raw string.
    init?(rawStorage: String) {
        switch rawStorage {
        case "smAppService": self = .smAppService
        case "smJobBless":   self = .smJobBless
        default:             return nil
        }
    }
}

// MARK: - ChooserSheetPresenter

/// Availability-safe bridge: invisible background View that presents InstallMethodChooserSheet.
/// macOS 12 receives an EmptyView; macOS 13+ presents the chooser sheet.
struct ChooserSheetPresenter: View {
    @Binding var isPresented: Bool
    @Binding var preferredMethodRaw: String
    let onInstall: (InstallMethod) -> Void
    let onCancel: () -> Void

    var body: some View {
        if #available(macOS 13, *) {
            ChooserSheetPresenter13(
                isPresented: $isPresented,
                preferredMethodRaw: $preferredMethodRaw,
                onInstall: onInstall,
                onCancel: onCancel
            )
        } else {
            EmptyView()
        }
    }
}

@available(macOS 13, *)
private struct ChooserSheetPresenter13: View {
    @Binding var isPresented: Bool
    @Binding var preferredMethodRaw: String
    let onInstall: (InstallMethod) -> Void
    let onCancel: () -> Void

    var body: some View {
        Color.clear
            .sheet(isPresented: $isPresented) {
                InstallMethodChooserSheet(
                    preferredMethodRaw: $preferredMethodRaw,
                    onInstall: onInstall,
                    onCancel: onCancel
                )
            }
    }
}
