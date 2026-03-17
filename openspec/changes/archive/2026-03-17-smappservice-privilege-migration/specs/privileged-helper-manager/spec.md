## ADDED Requirements

### Requirement: PrivilegedHelperManager exposes supported installation methods
`PrivilegedHelperManager` SHALL provide a `supportedMethods: [InstallMethod]` property that returns the ordered list of installation methods available on the current OS, with the most preferred method first.

- On macOS 14 and later: `[.smAppService, .smJobBless]`
- On macOS 12 and 13: `[.smJobBless]`

`InstallMethod` SHALL be an enum with cases `.smAppService` and `.smJobBless`.

#### Scenario: Supported methods on macOS 14+
- **WHEN** `supportedMethods` is read on macOS 14 or later
- **THEN** it returns `[.smAppService, .smJobBless]` in that order

#### Scenario: Supported methods on macOS 12–13
- **WHEN** `supportedMethods` is read on macOS 12 or 13
- **THEN** it returns `[.smJobBless]`

---

### Requirement: PrivilegedHelperManager derives activeMethod from live system state
`PrivilegedHelperManager` SHALL provide an `activeMethod: InstallMethod?` property derived from live OS state, not from a stored value. `nil` means the helper is not installed by any method.

Derivation logic:
- On macOS 14+:
  1. If `SMAppService.daemon(plistName: "cn.magicdian.staticrouter.helper.plist").status == .enabled` → `.smAppService`
  2. Else if the helper binary exists at `/Library/PrivilegedHelperTools/cn.magicdian.staticrouter.helper` **and** is registered with launchd (`launchctl print system/cn.magicdian.staticrouter.helper` succeeds) → `.smJobBless`
  3. Otherwise → `nil`
- On macOS 12–13: use the file system + launchctl check only → `.smJobBless` or `nil`

#### Scenario: SMAppService active on macOS 14+
- **WHEN** `SMAppService.daemon(plistName:).status` returns `.enabled`
- **THEN** `activeMethod` returns `.smAppService`

#### Scenario: SMJobBless fallback active on macOS 14+
- **WHEN** `SMAppService.daemon(plistName:).status` is not `.enabled`, but the helper binary is present and registered with launchd
- **THEN** `activeMethod` returns `.smJobBless`

#### Scenario: Not installed on macOS 14+
- **WHEN** neither SMAppService nor the file-system check finds the helper
- **THEN** `activeMethod` returns `nil`

#### Scenario: SMJobBless active on macOS 12–13
- **WHEN** the helper binary is present and registered with launchd on macOS 12 or 13
- **THEN** `activeMethod` returns `.smJobBless`

#### Scenario: Leftover binary without launchd registration not counted
- **WHEN** the helper binary exists at `/Library/PrivilegedHelperTools/` but `launchctl print` fails for its label
- **THEN** `activeMethod` returns `nil` (not counted as installed)

---

### Requirement: PrivilegedHelperManager exposes isOptimizedMode
`PrivilegedHelperManager` SHALL provide an `isOptimizedMode: Bool` property. It returns `true` if and only if `activeMethod == supportedMethods.first`. It returns `false` if `activeMethod` is `nil` or is not the highest-priority supported method.

#### Scenario: SMAppService active on macOS 14+ is optimized
- **WHEN** `activeMethod == .smAppService` on macOS 14+
- **THEN** `isOptimizedMode` returns `true`

#### Scenario: SMJobBless active on macOS 14+ is not optimized
- **WHEN** `activeMethod == .smJobBless` on macOS 14+
- **THEN** `isOptimizedMode` returns `false`

#### Scenario: SMJobBless active on macOS 12–13 is optimized
- **WHEN** `activeMethod == .smJobBless` on macOS 12 or 13 (the only supported method)
- **THEN** `isOptimizedMode` returns `true`

#### Scenario: Not installed is not optimized
- **WHEN** `activeMethod == nil`
- **THEN** `isOptimizedMode` returns `false`

---

### Requirement: install() attempts SMAppService first on macOS 14+, with structured result
On macOS 14+, `PrivilegedHelperManager.install()` SHALL attempt `SMAppService` registration first. It SHALL return an `InstallResult` to the caller rather than silently falling back.

```swift
enum InstallResult {
    case success(method: InstallMethod)
    case smAppServiceFailedFallbackAvailable(error: Error)
    case failed(error: Error)
}
```

- If `SMAppService.register()` succeeds → `.success(method: .smAppService)`
- If `SMAppService.register()` throws → `.smAppServiceFailedFallbackAvailable(error:)`
- On macOS 12–13, or after explicit fallback confirmation, call SMJobBless directly; return `.success(method: .smJobBless)` or `.failed(error:)`

The caller (UI / `RouterService`) is responsible for presenting the fallback confirmation dialog and calling `installFallback()` if the user confirms.

#### Scenario: SMAppService succeeds on macOS 14+
- **WHEN** `install()` is called on macOS 14+ and `SMAppService.register()` succeeds
- **THEN** `install()` returns `.success(method: .smAppService)` and `activeMethod` becomes `.smAppService`

#### Scenario: SMAppService fails, fallback available
- **WHEN** `install()` is called on macOS 14+ and `SMAppService.register()` throws
- **THEN** `install()` returns `.smAppServiceFailedFallbackAvailable(error:)` without installing anything

#### Scenario: installFallback() installs via SMJobBless
- **WHEN** `installFallback()` is called after user confirms the dialog
- **THEN** SMJobBless installation is attempted; on success `activeMethod` becomes `.smJobBless`

#### Scenario: macOS 12–13 install goes directly to SMJobBless
- **WHEN** `install()` is called on macOS 12 or 13
- **THEN** SMJobBless is invoked directly; result is `.success(method: .smJobBless)` or `.failed(error:)`

---

### Requirement: upgrade() migrates from SMJobBless to SMAppService and cleans up
`PrivilegedHelperManager.upgrade()` SHALL be available on macOS 14+ when `activeMethod == .smJobBless`. It SHALL:
1. Call `SMAppService.daemon(plistName:).register()`.
2. On success, immediately send an XPC `uninstallRoute` message to the currently-running SMJobBless helper to trigger `SelfUninstaller` (launchctl unload + file deletion).
3. Refresh `activeMethod` — it SHALL now return `.smAppService`.
4. `isOptimizedMode` SHALL become `true`.

If `SMAppService.register()` fails, `upgrade()` SHALL throw the error. `activeMethod` and `isOptimizedMode` SHALL remain unchanged. The failure SHALL not affect the running SMJobBless helper.

#### Scenario: Successful upgrade from SMJobBless to SMAppService
- **WHEN** `upgrade()` is called with `activeMethod == .smJobBless` on macOS 14+ and SMAppService registration succeeds
- **THEN** XPC self-uninstall is sent to the SMJobBless helper, `activeMethod` becomes `.smAppService`, `isOptimizedMode` becomes `true`

#### Scenario: Upgrade fails, legacy helper untouched
- **WHEN** `upgrade()` is called and `SMAppService.register()` throws
- **THEN** no XPC message is sent, the SMJobBless helper continues running, `activeMethod` remains `.smJobBless`

#### Scenario: upgrade() not available on macOS 12–13
- **WHEN** `upgrade()` is called on macOS 12 or 13
- **THEN** the call is a no-op or compile-time unavailable (gated by `@available(macOS 14, *)`)

---

### Requirement: uninstall() uses the path matching activeMethod
`PrivilegedHelperManager.uninstall()` SHALL route to the correct uninstallation mechanism based on `activeMethod`:
- `.smAppService` → `SMAppService.daemon(plistName:).unregister()`
- `.smJobBless` → send XPC `uninstallRoute` message to helper (triggers `SelfUninstaller`)
- `nil` → no-op

After uninstallation, `activeMethod` SHALL return `nil` and `isOptimizedMode` SHALL return `false`.

#### Scenario: Uninstall SMAppService-installed helper
- **WHEN** `uninstall()` is called with `activeMethod == .smAppService` on macOS 14+
- **THEN** `SMAppService.unregister()` is called; on completion `activeMethod` becomes `nil`

#### Scenario: Uninstall SMJobBless-installed helper
- **WHEN** `uninstall()` is called with `activeMethod == .smJobBless`
- **THEN** XPC `uninstallRoute` is sent; helper removes its files; `activeMethod` becomes `nil`

#### Scenario: Uninstall when not installed is a no-op
- **WHEN** `uninstall()` is called with `activeMethod == nil`
- **THEN** no system calls are made and no error is thrown

---

### Requirement: App launch triggers upgrade prompt when isOptimizedMode is false on macOS 14+
On every app launch, if `isOptimizedMode == false` and the OS is macOS 14+, the app SHALL present a prompt informing the user that a better installation method is available and offering to upgrade. There is no "don't ask again" option. The prompt is shown until the user upgrades.

#### Scenario: Upgrade prompt shown on every launch when SMJobBless is active on macOS 14+
- **WHEN** the app launches on macOS 14+ with `activeMethod == .smJobBless`
- **THEN** an upgrade prompt is displayed on every launch

#### Scenario: No upgrade prompt when already optimized
- **WHEN** the app launches with `isOptimizedMode == true`
- **THEN** no upgrade prompt is shown

#### Scenario: No upgrade prompt on macOS 12–13
- **WHEN** the app launches on macOS 12 or 13
- **THEN** no upgrade prompt is shown, regardless of `isOptimizedMode`

---

### Requirement: SMAppService status requiresApproval is surfaced distinctly
When `SMAppService.daemon(plistName:).status == .requiresApproval`, `PrivilegedHelperManager` SHALL expose this as a distinct state that the UI can display with instructions to approve in System Settings > Login Items & Extensions.

#### Scenario: requiresApproval state exposed
- **WHEN** `SMAppService.status` returns `.requiresApproval` after `register()` was called
- **THEN** `activeMethod` returns `nil` (not yet active) and a separate `isPendingApproval: Bool` property returns `true`

#### Scenario: isPendingApproval clears after user approves
- **WHEN** the user approves the helper in System Settings
- **THEN** on next state refresh, `SMAppService.status` returns `.enabled`, `activeMethod` returns `.smAppService`, `isPendingApproval` returns `false`

---

### Requirement: SMJobBless path fully unchanged on macOS 12 and 13
On macOS 12 and 13, `PrivilegedHelperManager` SHALL invoke the existing `Blessed`-package-based SMJobBless installation, with no changes to the helper binary, embedded plists, entitlements, or uninstallation flow.

#### Scenario: Install on macOS 12
- **WHEN** `install()` is called on macOS 12
- **THEN** `PrivilegedHelperManager.shared.authorizeAndBless(…)` (Blessed package) is called; helper is copied to `/Library/PrivilegedHelperTools/`; plist is written to `/Library/LaunchDaemons/`; daemon starts

#### Scenario: Install on macOS 13
- **WHEN** `install()` is called on macOS 13
- **THEN** same SMJobBless flow as macOS 12; SMAppService is NOT used
