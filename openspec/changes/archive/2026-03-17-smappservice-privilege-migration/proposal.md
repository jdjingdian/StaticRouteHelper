## Why

Apple's `SMJobBless` API has been deprecated since macOS 13 in favor of `SMAppService`, which offers a streamlined daemon registration model without the legacy launchd injection ceremony. The project already requires macOS 14+ for SwiftData features, and shipping a 2.0 major release is the right moment to adopt the modern API on macOS 14+ while preserving full backward compatibility for users on macOS 12–13.

The original design branched purely on OS version. This change refines that approach: on macOS 14+, `SMAppService` is attempted first, with automatic fallback to `SMJobBless` if it fails, and a managed upgrade path when the legacy method is already installed. A dedicated **PrivilegedHelperManager** layer owns this orchestration, keeping `RouterService` and the UI decoupled from installation mechanism details.

## What Changes

- **New `PrivilegedHelperManager` orchestration layer**: A new service object that owns all privilege-escalation logic. It exposes a stable interface (supported methods, active method, optimized-mode flag, install, uninstall) and hides whether `SMAppService` or `SMJobBless` is active underneath.
- **Install with fallback (macOS 14+)**: `PrivilegedHelperManager.install()` attempts `SMAppService` first. If that fails, it prompts the user to confirm before falling back to `SMJobBless`.
- **Upgrade prompt on every launch (macOS 14+, legacy installed)**: When the active method is `SMJobBless` on a macOS 14+ system (`isOptimizedMode == false`), the app prompts on every launch whether the user wants to upgrade to `SMAppService`. Apple recommends the newer API, so the prompt is shown every time until the user upgrades.
- **Automatic SMJobBless cleanup after upgrade**: When `SMAppService` registration succeeds during an upgrade, `PrivilegedHelperManager` sends an XPC self-uninstall message to the still-running SMJobBless helper, then `SMAppService` takes over with its own daemon instance.
- **Active method tracked from system state, not OS version**: `activeMethod` is derived at runtime by interrogating `SMAppService.status` (for the `SMAppService` path) and the file system / `launchctl` (for the `SMJobBless` path), not by reading the OS version.
- **`isOptimizedMode` property**: Reflects whether the currently active installation method is the best one available on this OS version.
- **Legacy path fully preserved for macOS 12–13**: `SMJobBless` remains the only installation path on macOS 12 and 13. No behavioral changes.
- **Helper XPC protocol unchanged**: The `SecureXPC` Mach service and all XPC routes remain unchanged. Only the installation and uninstallation mechanism changes.
- **UI updated**: General Settings shows the active installation method when the helper is installed, and surfaces the `isOptimizedMode == false` state with an upgrade prompt.
- **Version bump to 2.0.0**: `MARKETING_VERSION` updated to `2.0.0`.

## Capabilities

### New Capabilities

- `privileged-helper-manager`: The orchestration layer that manages installation method selection, fallback, upgrade prompting, and cleanup across `SMAppService` and `SMJobBless`.

### Modified Capabilities

- `smappservice-install`: Now describes the `SMAppService` path as one strategy managed by `PrivilegedHelperManager`, not the sole macOS 14+ path.
- `router-service`: `installHelper()` and `uninstallHelper()` delegate entirely to `PrivilegedHelperManager`; status is derived from its `activeMethod` and `isOptimizedMode`.
- `version-bump`: Version is being bumped to 2.0.0 as part of this release.

## Impact

- **New file `StaticRouter/Services/PrivilegedHelperManager.swift`**: Core orchestration layer.
- **`StaticRouter/Services/RouterService.swift`**: Install/uninstall calls replaced with `PrivilegedHelperManager` delegation; `helperStatus` derivation reads from the manager.
- **`StaticRouter/Components/HelperToolMonitor.swift`**: State detection logic moves into `PrivilegedHelperManager`; the monitor may be simplified or absorbed.
- **`StaticRouter/View/SettingsView/SettingsSubViews/GeneralSettings_HelperStateView.swift`**: Shows active install method text and upgrade prompt when `isOptimizedMode == false`.
- **`Resources/Locale/en.lproj/Localizable.strings`** and **`zh-Hans.lproj/Localizable.strings`**: New keys for active method display and upgrade prompt copy.
- **`RouteHelper/Launchd.plist`** and build phases: Plist also placed at `Contents/Library/LaunchDaemons/` for `SMAppService`; binary-embedded section retained for `SMJobBless` path.
- **`project.pbxproj`**: `MARKETING_VERSION` → `2.0.0`.
- No changes to the XPC protocol, `PFRouteWriter`, or any UI layer beyond Settings > General.
