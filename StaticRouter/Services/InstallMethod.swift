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

/// The outcome of a `PrivilegedHelperManager.install()` call.
enum InstallResult {
    /// Installation succeeded via the specified method.
    case success(method: InstallMethod)
    /// SMAppService registration failed; the user may fall back to SMJobBless.
    case smAppServiceFailedFallbackAvailable(error: Error)
    /// Installation failed with no available fallback.
    case failed(error: Error)
}
