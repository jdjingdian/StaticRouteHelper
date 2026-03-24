//
//  SettingsNavigator.swift
//  StaticRouteHelper
//
//  Legacy settings navigation helper (macOS 12-13).
//

import AppKit
import Foundation
import os
import SwiftUI

enum SettingsNavigator {
    private static let logger = Logger(subsystem: "cn.magicdian.staticrouter", category: "settings-navigation")

    /// Opens the app settings window via selector fallbacks for macOS 12-13.
    /// Returns true when an action was successfully dispatched.
    @MainActor
    @discardableResult
    static func openAppSettings() -> Bool {
        let settingsWindowSelector = Selector(("showSettingsWindow:"))
        let preferencesWindowSelector = Selector(("showPreferencesWindow:"))

        if NSApp.sendAction(settingsWindowSelector, to: nil, from: nil) {
            logger.info("Opened settings via showSettingsWindow: fallback")
            NSApp.activate(ignoringOtherApps: true)
            return true
        }

        if NSApp.sendAction(preferencesWindowSelector, to: nil, from: nil) {
            logger.info("Opened settings via showPreferencesWindow: fallback")
            NSApp.activate(ignoringOtherApps: true)
            return true
        }

        logger.error("Failed to open settings window using all known legacy actions")
        NSApp.activate(ignoringOtherApps: true)
        return false
    }

    /// Unified settings entry for SwiftUI views.
    /// - macOS 14+: uses SettingsLink to open Settings scene.
    /// - macOS 12-13: falls back to selector-based window opening.
    struct Entry<Label: View>: View {
        @ViewBuilder let label: () -> Label

        var body: some View {
            if #available(macOS 14, *) {
                SettingsLink {
                    label()
                }
            } else {
                Button {
                    SettingsNavigator.openAppSettings()
                } label: {
                    label()
                }
            }
        }
    }
}
