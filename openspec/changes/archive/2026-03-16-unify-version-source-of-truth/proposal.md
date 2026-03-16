## Why

The project currently has two independent version definitions — `MARKETING_VERSION` in `project.pbxproj` (controls the app's displayed version) and `CFBundleVersion` in `RouteHelper/Info.plist` (controls Helper upgrade detection) — that are kept in sync manually with no enforcement. A developer bumping one location and forgetting the other produces a mismatch: the About panel shows the wrong version, or the app fails to prompt for Helper reinstallation. This is version 1.3.1, the right moment to establish a single authoritative source before the manual process becomes a recurring bug.

## What Changes

- Add `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` Xcode build settings to **both** the `RouteHelper` and `Static Router` targets so the version lives in one place (`project.pbxproj`).
- Update `RouteHelper/Info.plist` to replace the hardcoded `CFBundleVersion` literal with the `$(CURRENT_PROJECT_VERSION)` variable reference, so Xcode injects the value at build time.
- Update `StaticRouter/Info.plist` to replace the hardcoded `CFBundleVersion` literal (`1`) with `$(CURRENT_PROJECT_VERSION)` as well, keeping both targets' bundle versions consistent.
- Set both build settings to `1.3.1` as part of this change (the version bump for this release).
- Remove the now-redundant hardcoded `1.3.0` literal from `RouteHelper/Info.plist`.

## Capabilities

### New Capabilities

- `unified-version-build-setting`: A single `CURRENT_PROJECT_VERSION` build setting in `project.pbxproj` drives `CFBundleVersion` in both the main app and the Helper tool Info.plist files via variable substitution, eliminating duplicate manual version maintenance.

### Modified Capabilities

_(none — no existing spec-level requirements change; this is a build configuration change only)_

## Impact

- `StaticRouteHelper.xcodeproj/project.pbxproj`: Add/update `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` build settings for both targets.
- `RouteHelper/Info.plist`: Replace hardcoded `1.3.0` with `$(CURRENT_PROJECT_VERSION)`.
- `StaticRouter/Info.plist`: Replace hardcoded `1` with `$(CURRENT_PROJECT_VERSION)` for `CFBundleVersion`.
- No Swift source changes required — `HelperToolInfoPropertyList` reads `CFBundleVersion` at runtime, so Xcode variable substitution is transparent.
- No XPC protocol or upgrade-detection logic changes.
