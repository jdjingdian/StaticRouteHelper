## Context

The project contains two targets — `Static Router` (the main app) and `RouteHelper` (the privileged helper daemon). Their version numbers currently live in three distinct locations:

1. **`RouteHelper/Info.plist` → `CFBundleVersion`** (e.g., `1.3.0`): hardcoded literal. This is the definitive version embedded into the Helper binary via the `-sectcreate __TEXT __info_plist` linker flag. It is what `HelperToolInfoPropertyList` reads at runtime to drive upgrade detection in `RouterService.resolveInstallationState()`.
2. **`project.pbxproj` → `MARKETING_VERSION`** (e.g., `1.3.0`): the `Static Router` target's marketing version. Referenced by `StaticRouter/Info.plist` via `$(MARKETING_VERSION)` to populate `CFBundleShortVersionString`, which the About panel displays.
3. **`StaticRouter/Info.plist` → `CFBundleVersion`**: hardcoded `1` (static, never incremented).

There is no `CURRENT_PROJECT_VERSION` build setting. The Helper's version is wholly independent of the app target's build settings. When bumping a release, a developer must update `RouteHelper/Info.plist` and `project.pbxproj` separately with no automated check that they agree.

Xcode supports variable substitution in plist files: any `$(VAR)` reference is replaced with the corresponding build setting at build time. This makes it straightforward to centralise version values in build settings without changing any Swift source.

## Goals / Non-Goals

**Goals:**
- A single `CURRENT_PROJECT_VERSION` build setting in `project.pbxproj` drives `CFBundleVersion` in both Info.plist files.
- `MARKETING_VERSION` (app display version) and `CURRENT_PROJECT_VERSION` (build/helper version) are kept equal and both live in `project.pbxproj`, so one place is edited per release.
- Both values are set to `1.3.1` as part of this change.
- All existing runtime behaviour (upgrade detection, About panel display) continues to work identically.

**Non-Goals:**
- Automating version bumps (scripts, CI workflows, fastlane, etc.) — out of scope.
- Changing the upgrade detection logic or the `BundleVersion` comparison mechanism.
- Adding `CFBundleShortVersionString` to `RouteHelper/Info.plist` — it is intentionally absent there.
- Modifying any Swift source files.

## Decisions

### Decision 1: Use `CURRENT_PROJECT_VERSION` for `CFBundleVersion`, `MARKETING_VERSION` for `CFBundleShortVersionString`

Xcode's conventional split is `CURRENT_PROJECT_VERSION` → `CFBundleVersion` (build number) and `MARKETING_VERSION` → `CFBundleShortVersionString` (user-facing version). We will keep both values identical (e.g., both `1.3.1`) to maintain the existing behaviour where `CFBundleVersion` already carries the full semantic version string (`1.3.0`). We do not introduce a separate integer build counter.

**Alternative considered:** Use `MARKETING_VERSION` for both. Rejected because `CURRENT_PROJECT_VERSION` is the conventional key Xcode AGV tooling expects for `CFBundleVersion`, and App Store Connect validates `CFBundleVersion` against `CURRENT_PROJECT_VERSION` when `VERSIONING_SYSTEM` is set. Keeping the conventional mapping avoids future friction.

### Decision 2: Add `CURRENT_PROJECT_VERSION` to both targets' build configurations

Both `Debug` and `Release` configurations for both `Static Router` and `RouteHelper` get `CURRENT_PROJECT_VERSION = 1.3.1`. This ensures that regardless of which scheme is built, the embedded version is consistent. The Helper binary's embedded plist must carry the correct version for upgrade detection to work in both configurations.

**Alternative considered:** Only add to `RouteHelper` target. Rejected because the app's `CFBundleVersion` should also be consistent with the Helper version for App Store submission purposes.

### Decision 3: Keep `RouteHelper/Info.plist` minimal — replace literal with `$(CURRENT_PROJECT_VERSION)` only

The Helper's plist already omits `CFBundleShortVersionString`. We only change `CFBundleVersion` from `1.3.0` to `$(CURRENT_PROJECT_VERSION)`. No new keys are added. The `-sectcreate` linker flag embeds the plist post-substitution, so the binary receives the resolved value.

**Important:** Xcode's `INFOPLIST_PREPROCESS` / Info.plist substitution happens when Xcode processes the file via its build system. However, since `RouteHelper` uses `OTHER_LDFLAGS` to embed the plist via `-sectcreate` (not via the standard `INFOPLIST_FILE` processed copy), we must verify that Xcode performs variable substitution on the raw plist before it is passed to the linker. If it does not, the embedded plist will contain the literal `$(CURRENT_PROJECT_VERSION)` string rather than the resolved value, breaking upgrade detection.

**Mitigation (see Risks):** Verify by building and extracting the embedded segment after the change.

### Decision 4: No `VERSIONING_SYSTEM` change

We do not set `VERSIONING_SYSTEM = apple-generic` (which would enable `agvtool` / automatic build number injection from `CURRENT_PROJECT_VERSION`). That system overwrites plist values during build and can conflict with manual variable substitution. We rely purely on Xcode's standard plist variable expansion, which is independent.

## Risks / Trade-offs

**[Risk] `-sectcreate` may not expand plist variables before embedding** → If `OTHER_LDFLAGS -sectcreate` uses the raw source plist (before Xcode's Info.plist processing step), the embedded `__info_plist` segment would contain `$(CURRENT_PROJECT_VERSION)` as a literal string. `HelperToolInfoPropertyList` would then fail to parse a valid `BundleVersion` from it, causing the Helper to appear unreadable and the app to show `.notInstalled`.

**Mitigation:** After implementing, build `RouteHelper` and run:
```bash
strings <built-helper-binary> | grep -E '^[0-9]+\.[0-9]'
```
or inspect with `otool -s __TEXT __info_plist`. If the value is still `$(CURRENT_PROJECT_VERSION)`, the `INFOPLIST_FILE` + processed copy approach must be used instead: add the plist as a processed copy resource and remove it from `OTHER_LDFLAGS`, letting Xcode embed it automatically via the standard `INFOPLIST_FILE` mechanism, which does perform variable substitution.

**[Risk] `StaticRouter/Info.plist` `CFBundleVersion` changing from `1` to `1.3.1`** → In theory, App Store Connect requires `CFBundleVersion` to be monotonically increasing across submissions. Changing from `1` to `1.3.1` satisfies this. However, if the string `1.3.1` is not accepted as a valid build number (App Store expects integers or dot-separated integers for `CFBundleVersion`), this could block a future submission.

**Mitigation:** `1.3.1` is a valid dot-separated integer triplet, accepted by App Store Connect. If a pure integer build counter is ever needed, `CURRENT_PROJECT_VERSION` can be split from `MARKETING_VERSION` at that point.

**[Risk] Developer forgets to update `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` in both Debug and Release configs** → This is the same class of problem as before but localised to one file. Acceptable residual risk; a future script-based bump could address it.

## Migration Plan

1. Edit `project.pbxproj`: add `CURRENT_PROJECT_VERSION = 1.3.1` and set `MARKETING_VERSION = 1.3.1` in all four build configurations (Static Router Debug/Release, RouteHelper Debug/Release).
2. Edit `RouteHelper/Info.plist`: change `CFBundleVersion` value from `1.3.0` to `$(CURRENT_PROJECT_VERSION)`.
3. Edit `StaticRouter/Info.plist`: change `CFBundleVersion` value from `1` to `$(CURRENT_PROJECT_VERSION)`.
4. Build `RouteHelper` target; verify with `otool -s __TEXT __info_plist` that the embedded plist contains `1.3.1`.
5. Build `Static Router` target; verify build succeeds and About panel shows `1.3.1`.
6. If step 4 reveals unresolved variable, switch to the `INFOPLIST_FILE` processed-copy approach and remove the manual `-sectcreate` for `__info_plist`.

**Rollback:** Revert to hardcoded `1.3.0` literals in both Info.plist files if variable substitution proves incompatible with the `-sectcreate` linker embedding approach.
