//
//  StatusBanner.swift
//  StaticRouteHelper
//
//  Generic status banner shown at the top of the main window detail area.
//  Replaces the previous HelperNotInstalledBanner with a reusable, style-parametric component.
//

import SwiftUI

// MARK: - BannerStyle

enum BannerStyle {
    /// Warning condition — yellow tint. Used for "helper not installed" states.
    case warning
    /// Informational — blue tint. Used for "better method available" suggestions.
    case info

    var backgroundColor: Color {
        switch self {
        case .warning: return .yellow.opacity(0.12)
        case .info:    return .blue.opacity(0.12)
        }
    }

    var iconName: String {
        switch self {
        case .warning: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .warning: return .yellow
        case .info:    return .blue
        }
    }
}

// MARK: - StatusBanner

/// Generic banner with a style-driven icon/background and an arbitrary action button.
/// Use the `@ViewBuilder actionButton` parameter to supply any button type (plain Button
/// or SettingsLink) so callers control the navigation target.
struct StatusBanner<ActionButton: View>: View {
    let style: BannerStyle
    let message: LocalizedStringKey
    @ViewBuilder let actionButton: () -> ActionButton

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: style.iconName)
                    .foregroundStyle(style.iconColor)
                Text(message)
                    .font(.callout)
                Spacer()
                actionButton()
                    .font(.callout)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(style.backgroundColor)
            Divider()
        }
    }
}
