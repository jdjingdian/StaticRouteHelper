## ADDED Requirements

### Requirement: CURRENT_PROJECT_VERSION build setting drives CFBundleVersion in both targets
The system SHALL define `CURRENT_PROJECT_VERSION` as a build setting in `project.pbxproj` for both the `Static Router` and `RouteHelper` target build configurations (Debug and Release). Both `RouteHelper/Info.plist` and `StaticRouter/Info.plist` SHALL reference this setting via `$(CURRENT_PROJECT_VERSION)` in their `CFBundleVersion` key, so that updating a single value in the Xcode project file updates the version embedded in both built products.

#### Scenario: Single edit propagates to both binaries
- **WHEN** a developer changes only `CURRENT_PROJECT_VERSION` in `project.pbxproj` and builds both targets
- **THEN** the `CFBundleVersion` embedded in the built `RouteHelper` binary (via `__info_plist` segment) and the `CFBundleVersion` in the built `Static Router.app/Contents/Info.plist` both reflect the new value without any additional file edits

#### Scenario: RouteHelper Info.plist contains no hardcoded version literal
- **WHEN** `RouteHelper/Info.plist` is read as a source file
- **THEN** the `CFBundleVersion` value is `$(CURRENT_PROJECT_VERSION)` and NOT a hardcoded version string such as `1.3.0`

#### Scenario: StaticRouter Info.plist contains no hardcoded CFBundleVersion literal
- **WHEN** `StaticRouter/Info.plist` is read as a source file
- **THEN** the `CFBundleVersion` value is `$(CURRENT_PROJECT_VERSION)` and NOT a hardcoded integer such as `1`

### Requirement: Helper upgrade detection continues to work after variable substitution
The system SHALL ensure that the `CFBundleVersion` embedded in the built `RouteHelper` binary contains the resolved numeric version string (e.g., `1.3.1`), not the unexpanded variable reference `$(CURRENT_PROJECT_VERSION)`. The existing `HelperToolInfoPropertyList` / `BundleVersion` runtime comparison in `RouterService.resolveInstallationState()` SHALL continue to correctly identify Helper binaries as `.installed`, `.needUpgrade`, or `.notCompatible` relative to the bundled Helper copy.

#### Scenario: Built RouteHelper binary embeds resolved version
- **WHEN** the `RouteHelper` target is built with `CURRENT_PROJECT_VERSION = 1.3.1`
- **THEN** the `__TEXT __info_plist` Mach-O segment of the resulting binary contains `<string>1.3.1</string>` for `CFBundleVersion`, not `<string>$(CURRENT_PROJECT_VERSION)</string>`

#### Scenario: Installed older Helper is detected as needing upgrade
- **WHEN** the installed Helper binary at `/Library/PrivilegedHelperTools/cn.magicdian.staticrouter.helper` has `CFBundleVersion` = `1.3.0` and the bundled Helper copy in the app has `CFBundleVersion` = `1.3.1`
- **THEN** `RouterService.helperStatus` equals `.needUpgrade` and the Settings UI displays the upgrade prompt

#### Scenario: Matching versions resolve as installed
- **WHEN** both the installed and bundled Helper binaries have `CFBundleVersion` = `1.3.1`
- **THEN** `RouterService.helperStatus` equals `.installed`

### Requirement: App display version is kept in sync with Helper version via MARKETING_VERSION
The system SHALL define `MARKETING_VERSION` as a build setting in `project.pbxproj` equal to `CURRENT_PROJECT_VERSION` for the `Static Router` target. The `StaticRouter/Info.plist` `CFBundleShortVersionString` SHALL continue to reference `$(MARKETING_VERSION)`. When both `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` are set to the same value, the About panel SHALL display a version string consistent with the Helper's embedded `CFBundleVersion`.

#### Scenario: About panel reflects the unified version
- **WHEN** both `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` are set to `1.3.1` and the app is launched
- **THEN** the About panel shows version `1.3.1` (read from `CFBundleShortVersionString` in the running app's `Info.plist`)
