## Why

The app's deployment target is locked to macOS 15.0, but a thorough API audit reveals no macOS 15-exclusive APIs are used—the actual minimum floor imposed by the current codebase is macOS 14.0 (SwiftData + @Observable). Lowering the deployment target to macOS 12.0 (Monterey) opens the app to a significantly larger installed base, while a conditional compilation strategy (`#available`) allows SwiftData and @Observable to remain the first-class experience on macOS 14+, with a Core Data + ObservableObject fallback on macOS 12–13.

## What Changes

- Lower `MACOSX_DEPLOYMENT_TARGET` from `15.0` to `12.0` across all build configurations (main app + helper tool).
- Introduce a `#available(macOS 14, *)` code split for the persistence layer: SwiftData on 14+, Core Data on 12–13.
- Replace `@Observable` / `import Observation` with `ObservableObject` + `@Published` for macOS 12–13 compatibility; use `#available` or protocol abstraction to share call sites.
- Replace the typed `@Environment(RouterService.self)` injection (macOS 14+) with `@EnvironmentObject` on older OS paths.
- Replace the two-argument `.onChange(of:) { _, _ in }` closures (macOS 14+) with the single-argument form on older OS paths.
- On macOS 12–13, deliver **Route CRUD only** (add, edit, delete, toggle routes); route group management is macOS 14+ only.
- System route view (read-only kernel table) is retained on all versions where the underlying SwiftUI `Table` APIs are available (macOS 12+).
- CoreDataMigrator (already existing) is leveraged for the legacy Core Data store; a new `LegacyPersistenceStack` wraps it for macOS 12–13 production use (not just migration).

## Capabilities

### New Capabilities

- `os-conditional-persistence`: Dual persistence layer—Core Data on macOS 12–13, SwiftData on macOS 14+. A shared protocol (`PersistenceStack`) abstracts CRUD so views remain version-agnostic where possible.
- `os-conditional-observable`: Observable state split—`@Observable` on macOS 14+, `ObservableObject` on macOS 12–13. `RouterService` adopts both via conditional compilation.
- `legacy-route-crud`: Route rule CRUD (add, edit, toggle, delete) implemented using Core Data models on macOS 12–13, mirroring the existing `route-crud` capability.

### Modified Capabilities

- `swiftdata-persistence`: SwiftData stack is now macOS 14+ only (guarded by `#available`); its interface is mirrored by `os-conditional-persistence` on older OS versions.
- `router-service`: `RouterService` gains conditional conformance to `@Observable` (14+) vs `ObservableObject` (12–13).
- `route-crud`: Route CRUD views gain `#available` guards or version-specific entry points; group-related actions are hidden on macOS 12–13.
- `system-route-view`: Minor view adjustments to remove any macOS 14+ SwiftUI APIs from the system route table path.

## Version

This change bumps the app version to **1.4.0**.

## Impact

- **Xcode project**: `MACOSX_DEPLOYMENT_TARGET` changed to `12.0` in all 6 build configuration entries.
- **`StaticRouteHelperApp.swift`**: `@main` entry gains `#available` branching for model container setup (SwiftData vs Core Data).
- **`RouterService.swift`**: Conditional compilation for `@Observable` vs `ObservableObject`; `@Environment` injection type changes at call sites.
- **`RouteRule.swift` / `RouteGroup.swift`**: SwiftData `@Model` types remain but are guarded; new `NSManagedObject` subclasses added for macOS 12–13.
- **All views using `@Query`**: Guards added; on 12–13 views use `@FetchRequest` or manual fetch-backed state.
- **`RouteEditSheet.swift`**: Two-argument `.onChange` calls replaced with version-safe equivalents.
- **`GroupSheets.swift`**: Group management UI hidden behind `#available(macOS 14, *)`.
- **Helper tool target**: Deployment target also lowered to 12.0; no functional code change needed (helper uses only BSD sockets and XPC).
- **New file**: `LegacyPersistenceStack.swift` — Core Data stack for macOS 12–13.
- **New files**: `RouteRuleMO.swift`, `RouteGroupMO.swift` — `NSManagedObject` subclasses mirroring the SwiftData models.
