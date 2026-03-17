## Context

Static Router uses SMJobBless to install a privileged helper daemon (`cn.magicdian.staticrouter.helper`) that writes kernel routing table entries via a `PF_ROUTE` raw socket. SMJobBless was deprecated in macOS 13 when Apple introduced `SMAppService`. The project already conditionally branches on macOS 14+ (SwiftData vs Core Data), so adding another OS-version branch is consistent with the existing architecture.

The initial design assumed OS version was sufficient to determine which installation method to use. User requirements have since clarified that on macOS 14+, `SMAppService` should be attempted first with automatic fallback to `SMJobBless` on failure, and that the active method must reflect actual system state rather than OS version. This requires a dedicated orchestration layer — `PrivilegedHelperManager` — to own installation strategy, state detection, fallback, and the upgrade lifecycle.

Current install flow (all macOS versions):
1. `RouterService.installHelper()` calls `PrivilegedHelperManager.shared.authorizeAndBless(…)` (from the `Blessed` package).
2. Helper binary is copied to `/Library/PrivilegedHelperTools/`, plist written to `/Library/LaunchDaemons/`, daemon started.
3. `HelperToolMonitor` polls file system + `launchctl print` for status.
4. Uninstall: `SelfUninstaller` inside the helper calls `launchctl unload` and deletes files.

Target architecture (macOS 14+):
```
RouterService
    └── PrivilegedHelperManager
            ├── supportedMethods: [.smAppService, .smJobBless]
            ├── activeMethod: InstallMethod?   (derived from system state)
            ├── isOptimizedMode: Bool           (activeMethod == supportedMethods.first)
            ├── install() async throws
            └── uninstall() async throws
                    ├── SMAppService strategy
                    └── SMJobBless strategy (Blessed package)
```

## Goals / Non-Goals

**Goals:**
- Introduce `PrivilegedHelperManager` as the single owner of installation strategy, state detection, fallback, and upgrade lifecycle.
- On macOS 14+: attempt `SMAppService` first; fall back to `SMJobBless` after user confirmation if it fails.
- On macOS 14+ with SMJobBless already active: prompt user to upgrade on every app launch until upgraded.
- After successful SMAppService upgrade: automatically clean up SMJobBless-installed files via XPC self-uninstall.
- `activeMethod` always reflects real system state, not OS version.
- `isOptimizedMode` indicates whether the best available method is active.
- UI shows the active method and surfaces upgrade opportunity.
- Full SMJobBless-only path on macOS 12–13, no behavioral changes.
- Bump marketing version to 2.0.0.

**Non-Goals:**
- Removing the `Blessed` package or SMJobBless code (deferred until macOS 12–13 support is dropped).
- Changing the XPC protocol or helper's privilege model.
- Code-signing / notarization pipeline changes.
- Suppressing the upgrade prompt (user must upgrade or live with the prompt every launch — this matches Apple's recommendation posture).

## Decisions

### Decision 1: Runtime OS branching, not compile-time targets

**Choice**: Use `if #available(macOS 14, *)` / `else` in Swift code, keeping a single binary that runs on macOS 12+.

**Rationale**: The project already uses this pattern for SwiftData vs Core Data. A single binary is simpler to ship. SMAppService daemon registration is guarded at macOS 14 (not 13) because reliability issues with third-party daemon registration were present on macOS 13.

**Alternative considered**: Raise the minimum deployment target to macOS 14. Rejected because macOS 12–13 support must be preserved.

---

### Decision 2: `Launchd.plist` placed in `Contents/Library/LaunchDaemons/` (in addition to binary-embedded section)

**Choice**: Add a `CopyFiles` build phase to the main app target that places `RouteHelper/Launchd.plist` at `Contents/Library/LaunchDaemons/cn.magicdian.staticrouter.helper.plist`. The helper target's `-sectcreate __TEXT __launchd_plist` linker flag is retained for the SMJobBless path.

**Rationale**: `SMAppService.daemon(plistName:)` resolves the plist from `Contents/Library/LaunchDaemons/` by filename. Both paths need to work from the same binary, so both the bundle copy and the embedded section must coexist. The plist content is identical; duplication is unavoidable but the single source file (`RouteHelper/Launchd.plist`) prevents drift.

---

### Decision 3: `PrivilegedHelperManager` as a dedicated orchestration layer

**Choice**: Create `StaticRouter/Services/PrivilegedHelperManager.swift` as a new `@Observable` (macOS 14+) / `ObservableObject` (macOS 12–13) service. `RouterService` holds a reference to it and delegates all install/uninstall/status calls.

**Rationale**: Without this layer, the fallback logic, upgrade prompt logic, state derivation, and cleanup sequencing would all live inside `RouterService`, which already has significant responsibilities (XPC communication, route activation, system route monitoring). Separation keeps each class focused and makes the installation strategies independently testable.

**Alternative considered**: Extend `HelperToolMonitor` to own installation. Rejected because the monitor's responsibility is observation, not mutation.

---

### Decision 4: `activeMethod` derived from system state, not stored

**Choice**: `PrivilegedHelperManager` computes `activeMethod: InstallMethod?` by interrogating live system state on every access (or on an explicit refresh):
- On macOS 14+: check `SMAppService.daemon(plistName:).status` first. If `.enabled` → `.smAppService`. Otherwise, check file system / `launchctl print` for the helper binary at `/Library/PrivilegedHelperTools/`. If present and registered → `.smJobBless`. Otherwise → `nil`.
- On macOS 12–13: check file system / `launchctl print` only → `.smJobBless` or `nil`.

**Rationale**: No persistent store is needed; the OS itself is the source of truth. `SMAppService.status` is synchronous and cheap. File system checks already exist in `HelperToolMonitor`. Deriving from state (not storing) means app restarts automatically reflect reality without migration logic.

**Alternative considered**: Persist the last-used method in `UserDefaults`. Rejected because it creates a stale-state problem if the user manually uninstalls the helper outside the app.

---

### Decision 5: Install fallback flow — user confirmation required before SMJobBless

**Choice**: When `SMAppService.register()` throws on macOS 14+, `PrivilegedHelperManager` surfaces the error to the caller with a structured result indicating "SMAppService failed; SMJobBless available as fallback". The UI (or `RouterService`) then presents a confirmation dialog. Only on explicit user confirmation does `install()` proceed with `SMJobBless`.

**Rationale**: Silently falling back to a deprecated API without user awareness is poor UX and could confuse users who later see "not in optimized mode". Making the fallback explicit keeps the user informed.

**API shape**:
```swift
enum InstallResult {
    case success(method: InstallMethod)
    case smAppServiceFailedFallbackAvailable(error: Error)
    case failed(error: Error)
}
```
The caller decides whether to prompt and whether to retry with SMJobBless via a separate `installFallback()` call.

---

### Decision 6: Upgrade prompt shown on every launch, no suppression

**Choice**: On app launch, if `isOptimizedMode == false` (SMJobBless active on macOS 14+), `PrivilegedHelperManager` exposes this state. The app displays an upgrade prompt every launch until the user upgrades.

**Rationale**: Apple officially recommends SMAppService as the replacement for SMJobBless. There is no "snooze" or "don't ask again" option — the user's choice is to upgrade or to continue seeing the prompt. This matches the severity of Apple's deprecation stance and avoids the complexity of a prompt-suppression preference.

**Upgrade sequence**:
1. Prompt shown; user confirms.
2. `PrivilegedHelperManager.upgrade()` calls `SMAppService.register()`.
3. On success: sends XPC `uninstallRoute` to the still-running SMJobBless helper → helper calls `SelfUninstaller` (launchctl unload + file deletion). SMAppService daemon instance takes over.
4. `activeMethod` refreshed → `.smAppService`. `isOptimizedMode` becomes `true`. Prompt no longer shown.
5. On failure: `activeMethod` stays `.smJobBless`. Prompt shown again next launch.

**Note on XPC timing**: The SMJobBless helper is still alive when `SMAppService.register()` completes (launchd starts a new instance; both may briefly coexist). The XPC self-uninstall message must be sent before the SMJobBless helper is terminated by launchd. `PrivilegedHelperManager` sends the message immediately after successful `register()`.

---

### Decision 7: Uninstall path determined by `activeMethod`

**Choice**: `PrivilegedHelperManager.uninstall()` reads `activeMethod` and routes accordingly:
- `.smAppService` → `SMAppService.daemon(plistName:).unregister()`
- `.smJobBless` → XPC `uninstallRoute` message to helper

**Rationale**: The uninstall mechanism must match the install mechanism. Using the wrong path (e.g., calling `SMAppService.unregister()` on a SMJobBless-installed daemon) would leave orphaned files or fail silently.

## Risks / Trade-offs

- **[Risk] Brief daemon overlap during upgrade**: Between `SMAppService.register()` succeeding and the SMJobBless helper processing the XPC uninstall message, two helper processes may be alive simultaneously. Both listen on the same Mach service name, so XPC routing during this window is non-deterministic.
  → **Mitigation**: Send the uninstall XPC message immediately and synchronously after `register()` returns. The SMJobBless helper is the one that registered the Mach service name first, so existing XPC connections resolve to it — the message will reach the right process. The SMAppService instance will take over the Mach service after the SMJobBless helper unloads.

- **[Risk] `SMAppService` requires user approval (macOS 14+)**: First-time registration via SMAppService prompts the user in System Settings > Login Items & Extensions. This is a UX change from the SMJobBless password dialog.
  → **Mitigation**: `isOptimizedMode == false` + upgrade prompt gives users a clear path. `requiresApproval` state is surfaced in UI with instructions to approve in System Settings.

- **[Risk] File system detection false positive**: A leftover `/Library/PrivilegedHelperTools/` binary (e.g., from a manual partial uninstall) could cause `activeMethod` to incorrectly report `.smJobBless`.
  → **Mitigation**: The file system check additionally validates `launchctl print system/<label>` registration, consistent with existing `HelperToolMonitor` logic. A binary without a registered launchd job is not counted as installed.

- **[Trade-off] Upgrade prompt shown every launch with no suppression**: Some users may find this aggressive.
  → **Accepted**: This is intentional per requirements. Apple's own deprecation guidance supports this posture.

- **[Trade-off] Two parallel install code paths**: Complexity in `PrivilegedHelperManager`. Accepted as transitional cost until macOS 12–13 support is dropped.

## Migration Plan

1. Implement `PrivilegedHelperManager` with both strategies and state derivation logic.
2. Add `Contents/Library/LaunchDaemons/` plist copy build phase.
3. Update `RouterService` to delegate to `PrivilegedHelperManager`.
4. Update `HelperToolMonitor` or absorb its detection logic into the manager.
5. Add UI changes (active method text, upgrade prompt).
6. Add localization keys to both locale files.
7. Bump version to 2.0.0.
8. Test: macOS 12 VM, macOS 13 VM, macOS 14+ (fresh install, fallback install, upgrade from SMJobBless).

**Rollback**: Remove `PrivilegedHelperManager`, restore `RouterService` direct calls to `Blessed`. No data migration needed.

## Open Questions

- Should `PrivilegedHelperManager` be a singleton (`shared`) or injected as a dependency into `RouterService`? (Dependency injection is preferred for testability but requires updating injection sites.)
- Should the upgrade prompt be a SwiftUI `Alert` or a dedicated sheet? (Alert is simpler; sheet allows richer explanation copy.)
