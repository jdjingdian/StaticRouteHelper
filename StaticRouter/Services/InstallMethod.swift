//
//  InstallMethod.swift
//  StaticRouter
//

import Foundation

// MARK: - InstallMethod

/// Represents the mechanism used to install the privileged helper daemon.
enum InstallMethod: Equatable {
    /// Modern Apple-recommended API (macOS 14+).
    case smAppService
    /// Legacy blessed helper (macOS 12–13 and fallback on 14+).
    case smJobBless
}

// MARK: - InstallResult

/// The outcome of a `PrivilegedHelperManager.install(method:)` call.
enum InstallResult {
    /// Installation succeeded via the specified method.
    case success(method: InstallMethod)
    /// Installation failed (user cancelled or system error).
    case failed(error: Error)
}
