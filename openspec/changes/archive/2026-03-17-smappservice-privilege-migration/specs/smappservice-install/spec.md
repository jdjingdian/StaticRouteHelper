## ADDED Requirements

### Requirement: SMAppService daemon registration
On macOS 14 and later, the SMAppService installation strategy SHALL register the privileged helper daemon by calling `SMAppService.daemon(plistName: "cn.magicdian.staticrouter.helper.plist").register()`. This is invoked by `PrivilegedHelperManager` as the primary (preferred) strategy.

#### Scenario: Successful first-time registration
- **WHEN** `SMAppService.register()` is called and the user approves in System Settings
- **THEN** the call returns without throwing, the daemon is started by launchd, and `PrivilegedHelperManager.activeMethod` becomes `.smAppService`

#### Scenario: Registration requires user approval
- **WHEN** `SMAppService.register()` is called and approval has not yet been granted
- **THEN** `SMAppService.status` returns `.requiresApproval`; `PrivilegedHelperManager.isPendingApproval` becomes `true`

#### Scenario: Already registered is idempotent
- **WHEN** `SMAppService.register()` is called and the daemon is already `.enabled`
- **THEN** the call completes without error and without creating a duplicate registration

### Requirement: SMAppService daemon unregistration
When `PrivilegedHelperManager.activeMethod == .smAppService`, uninstallation SHALL call `SMAppService.daemon(plistName: "cn.magicdian.staticrouter.helper.plist").unregister()` from the app process. The helper SHALL NOT self-uninstall via `SelfUninstaller` in this path.

#### Scenario: Successful unregistration
- **WHEN** `SMAppService.unregister()` is called while the daemon is registered
- **THEN** the daemon is terminated by launchd and `PrivilegedHelperManager.activeMethod` becomes `nil`

#### Scenario: Unregister when not registered is idempotent
- **WHEN** `SMAppService.unregister()` is called while the daemon is not registered
- **THEN** the call completes without throwing

### Requirement: Launchd plist bundled in app Contents/Library/LaunchDaemons/
The app bundle SHALL include `Contents/Library/LaunchDaemons/cn.magicdian.staticrouter.helper.plist` with the correct `Label` and `MachServices` entries. This is the plist resolved by `SMAppService.daemon(plistName:)`.

The plist file SHALL share the same source as `RouteHelper/Launchd.plist` to prevent content drift. The binary-embedded `__TEXT/__launchd_plist` section used by SMJobBless SHALL remain in place alongside the bundle copy.

#### Scenario: Plist present in bundle at build time
- **WHEN** the StaticRouter app target is built
- **THEN** the resulting `.app` bundle contains `Contents/Library/LaunchDaemons/cn.magicdian.staticrouter.helper.plist` with `Label = cn.magicdian.staticrouter.helper` and the correct `MachServices` dictionary

### Requirement: SMAppService status is the authoritative source for SMAppService path detection
`PrivilegedHelperManager` SHALL use `SMAppService.daemon(plistName:).status` as the first check when deriving `activeMethod` on macOS 14+. File-system detection is used only as a secondary check for the SMJobBless path.

#### Scenario: Status .enabled maps to activeMethod .smAppService
- **WHEN** `SMAppService.daemon(plistName:).status` returns `.enabled`
- **THEN** `PrivilegedHelperManager.activeMethod` returns `.smAppService`

#### Scenario: Status .notRegistered or .notFound does not imply SMAppService is active
- **WHEN** `SMAppService.daemon(plistName:).status` returns `.notRegistered` or `.notFound`
- **THEN** `PrivilegedHelperManager` proceeds to the secondary file-system check for SMJobBless
