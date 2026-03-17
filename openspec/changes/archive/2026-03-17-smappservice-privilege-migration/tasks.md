## 1. Build System — Bundle the Launchd Plist

- [x] 1.1 Add a `CopyFiles` build phase to the **StaticRouter** app target (via Xcode UI or `project.pbxproj`) that copies `RouteHelper/Launchd.plist` to destination **"Resources"** subfolder `LaunchDaemons` inside `Contents/Library/`, producing `Contents/Library/LaunchDaemons/cn.magicdian.staticrouter.helper.plist`
- [x] 1.2 Confirm the helper target's `-sectcreate __TEXT __launchd_plist` linker flag is still present (required for SMJobBless path on macOS 12–13)
- [x] 1.3 Build the app and verify `Contents/Library/LaunchDaemons/cn.magicdian.staticrouter.helper.plist` exists in the bundle with correct `Label` and `MachServices` keys

## 2. InstallMethod Enum and InstallResult Enum

- [x] 2.1 Create `StaticRouter/Services/InstallMethod.swift` defining:
  ```swift
  enum InstallMethod {
      case smAppService
      case smJobBless
  }
  ```
- [x] 2.2 Create `InstallResult` enum in the same file or alongside `PrivilegedHelperManager`:
  ```swift
  enum InstallResult {
      case success(method: InstallMethod)
      case smAppServiceFailedFallbackAvailable(error: Error)
      case failed(error: Error)
  }
  ```

## 3. PrivilegedHelperManager — Core Implementation

- [x] 3.1 Create `StaticRouter/Services/PrivilegedHelperManager.swift` as an `@Observable` (macOS 14+) / `ObservableObject` (macOS 12–13) class
- [x] 3.2 Implement `supportedMethods: [InstallMethod]` — returns `[.smAppService, .smJobBless]` on macOS 14+, `[.smJobBless]` on macOS 12–13
- [x] 3.3 Implement `activeMethod: InstallMethod?` with the two-step derivation:
  - macOS 14+: check `SMAppService.daemon(plistName:).status == .enabled` first → `.smAppService`; else check file system + `launchctl print` → `.smJobBless` or `nil`
  - macOS 12–13: file system + `launchctl print` only → `.smJobBless` or `nil`
- [x] 3.4 Implement `isPendingApproval: Bool` — returns `true` when `SMAppService.status == .requiresApproval` on macOS 14+
- [x] 3.5 Implement `isOptimizedMode: Bool` — returns `activeMethod == supportedMethods.first`
- [x] 3.6 Implement `refreshState()` method that re-derives `activeMethod`, `isPendingApproval`, and `isOptimizedMode` from live system state (to be called after install/uninstall and on app launch)

## 4. PrivilegedHelperManager — install() and installFallback()

- [x] 4.1 Implement `install() async throws -> InstallResult`:
  - macOS 14+: call `SMAppService.daemon(plistName:).register()`; on success return `.success(method: .smAppService)`; on failure return `.smAppServiceFailedFallbackAvailable(error:)`
  - macOS 12–13: call `Blessed` package `authorizeAndBless(…)`; return `.success(method: .smJobBless)` or `.failed(error:)`
- [x] 4.2 Implement `installFallback() async throws` — calls `Blessed` package SMJobBless installation on macOS 14+ (after user confirms dialog); calls `refreshState()` on success
- [x] 4.3 Ensure `refreshState()` is called after any successful install path

## 5. PrivilegedHelperManager — upgrade()

- [x] 5.1 Implement `upgrade() async throws` gated by `@available(macOS 14, *)`:
  1. Call `SMAppService.daemon(plistName:).register()`
  2. On success: immediately send XPC `uninstallRoute` message to the currently-running SMJobBless helper to trigger `SelfUninstaller`
  3. Call `refreshState()` — `activeMethod` should now be `.smAppService`
  4. On failure: do NOT send XPC message; call `refreshState()`; rethrow error
- [x] 5.2 Add a brief comment in code noting the XPC timing rationale (SMJobBless helper still alive, Mach service name resolves to it — message reaches the right process)

## 6. PrivilegedHelperManager — uninstall()

- [x] 6.1 Implement `uninstall() async throws`:
  - `activeMethod == .smAppService` → call `SMAppService.daemon(plistName:).unregister()`
  - `activeMethod == .smJobBless` → send XPC `uninstallRoute` message to helper
  - `activeMethod == nil` → no-op
  - Call `refreshState()` after each path
- [x] 6.2 Confirm `SelfUninstaller.swift` in the helper target is unchanged and handles the XPC `uninstallRoute` message correctly for both upgrade and uninstall paths

## 7. RouterService — Delegate to PrivilegedHelperManager

- [x] 7.1 Add `PrivilegedHelperManager` as a held reference in `RouterService` (injected or created at init)
- [x] 7.2 Replace `installHelper()` body with a call to `PrivilegedHelperManager.install()`, returning `InstallResult` to the caller (UI layer handles dialog on `.smAppServiceFailedFallbackAvailable`)
- [x] 7.3 Replace `uninstallHelper()` body with a call to `PrivilegedHelperManager.uninstall()`
- [x] 7.4 Derive `helperStatus: HelperInstallStatus` from `PrivilegedHelperManager.activeMethod` + version comparison (remove direct `HelperToolMonitor` status derivation if it is absorbed)
- [x] 7.5 Remove all `#available(macOS 14, *)` install/uninstall branching from `RouterService` itself — that logic now lives entirely in `PrivilegedHelperManager`

## 8. HelperToolMonitor — Simplify or Absorb

- [x] 8.1 Evaluate whether `HelperToolMonitor`'s `DispatchSource` file-watcher and `launchctl print` logic should be absorbed into `PrivilegedHelperManager.refreshState()` or remain as a separate observer
- [x] 8.2 If absorbed: remove `HelperToolMonitor.swift` or reduce it to a thin file-watching trigger that calls `PrivilegedHelperManager.refreshState()`
- [x] 8.3 If retained: ensure `HelperToolMonitor` no longer drives `helperStatus` directly — `PrivilegedHelperManager` is now the authority

## 9. UI — Fallback Confirmation Dialog

- [x] 9.1 In the install flow (triggered from `GeneralSettings_HelperStateView` or wherever install is called), handle `InstallResult.smAppServiceFailedFallbackAvailable(error:)` by presenting an alert:
  - Title: `settings.helper.fallback.alert.title`
  - Message: `settings.helper.fallback.alert.message`
  - Confirm: `settings.helper.fallback.alert.confirm` → calls `PrivilegedHelperManager.installFallback()`
  - Cancel: `settings.helper.fallback.alert.cancel`
- [x] 9.2 Add localization keys to `en.lproj/Localizable.strings`:
  ```
  "settings.helper.fallback.alert.title" = "Unable to Use New Installation Method";
  "settings.helper.fallback.alert.message" = "SMAppService registration failed. Would you like to install using the legacy method (SMJobBless)?";
  "settings.helper.fallback.alert.confirm" = "Use Legacy Method";
  "settings.helper.fallback.alert.cancel" = "Cancel";
  ```
- [x] 9.3 Add the same keys to `zh-Hans.lproj/Localizable.strings`:
  ```
  "settings.helper.fallback.alert.title" = "无法使用新安装方式";
  "settings.helper.fallback.alert.message" = "SMAppService 注册失败。是否使用旧版方式（SMJobBless）安装？";
  "settings.helper.fallback.alert.confirm" = "使用旧版方式";
  "settings.helper.fallback.alert.cancel" = "取消";
  ```

## 10. UI — Upgrade Prompt on App Launch

- [x] 10.1 On app launch (in the app's entry point or `RouterService` init), check `PrivilegedHelperManager.isOptimizedMode == false` (and `activeMethod != nil` and macOS 14+) — if true, present upgrade prompt
- [x] 10.2 Present the upgrade alert:
  - Title: `settings.helper.upgrade.alert.title`
  - Message: `settings.helper.upgrade.alert.message`
  - Confirm: `settings.helper.upgrade.alert.confirm` → calls `PrivilegedHelperManager.upgrade()`
  - Cancel: `settings.helper.upgrade.alert.cancel` → dismisses; prompt will appear again next launch
- [x] 10.3 Add localization keys to `en.lproj/Localizable.strings`:
  ```
  "settings.helper.upgrade.alert.title" = "Better Installation Method Available";
  "settings.helper.upgrade.alert.message" = "Your helper is installed via SMJobBless. Apple recommends SMAppService for macOS 14 and later. Would you like to upgrade now?";
  "settings.helper.upgrade.alert.confirm" = "Upgrade";
  "settings.helper.upgrade.alert.cancel" = "Later";
  ```
- [x] 10.4 Add the same keys to `zh-Hans.lproj/Localizable.strings`:
  ```
  "settings.helper.upgrade.alert.title" = "有更好的安装方式可用";
  "settings.helper.upgrade.alert.message" = "帮助程序当前通过 SMJobBless 安装。苹果推荐在 macOS 14 及更高版本上使用 SMAppService。是否立即升级？";
  "settings.helper.upgrade.alert.confirm" = "立即升级";
  "settings.helper.upgrade.alert.cancel" = "稍后";
  ```

## 11. UI — Active Method Display in General Settings

- [x] 11.1 In `GeneralSettings_HelperStateView.swift`, add a computed property `activationMethodText: String?` that reads `PrivilegedHelperManager.activeMethod` (not OS version) and returns the appropriate localized string:
  - `.smAppService` → `String(localized: "settings.helper.footer.installed.method.smappservice")`
  - `.smJobBless` → `String(localized: "settings.helper.footer.installed.method.smjobbless")`
  - `nil` → `nil`
  - Only non-nil when `helperStatus == .installed`
- [x] 11.2 Render `activationMethodText` in `body` with `if let`, placed immediately below `Text(helperStateFooter)`, styled `.font(.footnote).italic().foregroundStyle(.secondary)`
- [x] 11.3 Add localization keys to `en.lproj/Localizable.strings`:
  ```
  "settings.helper.footer.installed.method.smappservice" = "Managed by SMAppService (macOS 14+)";
  "settings.helper.footer.installed.method.smjobbless" = "Managed by SMJobBless (macOS 12–13)";
  ```
- [x] 11.4 Add the same keys to `zh-Hans.lproj/Localizable.strings`:
  ```
  "settings.helper.footer.installed.method.smappservice" = "由 SMAppService 管理（macOS 14+）";
  "settings.helper.footer.installed.method.smjobbless" = "由 SMJobBless 管理（macOS 12–13）";
  ```
- [x] 11.5 Handle `isPendingApproval == true` in the UI: show a distinct message with instructions to approve in System Settings > Login Items & Extensions (add corresponding localization key)

## 12. Version Bump

- [x] 12.1 Run `./scripts/bump-version.sh 2.0.0` to update `MARKETING_VERSION` to `2.0.0` and `CURRENT_PROJECT_VERSION` to the current git commit count
- [x] 12.2 Verify `grep MARKETING_VERSION StaticRouteHelper.xcodeproj/project.pbxproj` shows only `2.0.0`

## 13. Validation

- [ ] 13.1 Build with deployment target macOS 12.0 — zero compile errors, no exhaustiveness warnings on `InstallMethod` or `InstallResult` switch statements
- [ ] 13.2 macOS 14+ — fresh install: confirm `install()` returns `.success(method: .smAppService)`, daemon appears in `launchctl print system/cn.magicdian.staticrouter.helper`, `activeMethod == .smAppService`, `isOptimizedMode == true`
- [ ] 13.3 macOS 14+ — SMAppService failure simulation (e.g., remove bundle plist): confirm `install()` returns `.smAppServiceFailedFallbackAvailable`, fallback dialog appears, `installFallback()` installs via SMJobBless, `activeMethod == .smJobBless`, `isOptimizedMode == false`
- [ ] 13.4 macOS 14+ — app relaunch with SMJobBless active: confirm upgrade prompt appears, user confirms, `upgrade()` sends XPC uninstall to old helper, `activeMethod` becomes `.smAppService`, prompt absent on next launch
- [ ] 13.5 macOS 14+ — app relaunch with SMJobBless active, user cancels upgrade: confirm `activeMethod` remains `.smJobBless`, prompt appears again on next launch
- [ ] 13.6 macOS 14+ — route add/delete via XPC works regardless of which installation method is active
- [ ] 13.7 macOS 14+ — uninstall from SMAppService path: `SMAppService.unregister()` called, `activeMethod` becomes `nil`
- [ ] 13.8 macOS 14+ — uninstall from SMJobBless path: XPC `uninstallRoute` sent, helper self-deletes, `activeMethod` becomes `nil`
- [ ] 13.9 macOS 12 VM — install, use routes, uninstall: full SMJobBless flow unchanged
- [ ] 13.10 macOS 13 VM — same as 13.9; confirm SMAppService is never called
- [ ] 13.11 Localization — switch system language to English and Chinese, verify all new strings display correctly in General Settings
- [ ] 13.12 Run `SMJobBlessUtil.py check <path-to-app>` on a macOS 12/13 build to confirm plist/signature consistency
