## Context

StaticRouteHelper is a macOS privilege-separated app (SwiftUI front-end + SMJobBless helper tool) that manages static IPv4 routing rules. The current `MACOSX_DEPLOYMENT_TARGET` is hardcoded to `15.0` across all build configurations. An API audit confirms no macOS 15-exclusive APIs are actually used; the real floor is **macOS 14.0** (SwiftData + `@Observable` + Observation framework). This change lowers the target to **macOS 12.0** (Monterey), retaining full functionality on 14+ and delivering a streamlined route-CRUD-only experience on 12–13.

The project has two build targets:

- **Static Router.app** — SwiftUI app, uses SwiftData, `@Observable`, `@Query`, typed `@Environment`, two-arg `.onChange`.
- **`cn.magicdian.staticrouter.helper`** — privileged XPC daemon, uses only BSD sockets + XPC; no framework changes needed.

A `CoreDataMigrator` already exists in the codebase (for one-time Core Data → SwiftData migration), so a Core Data `NSPersistentContainer` stack is partly implemented and can be extended for production use on macOS 12–13.

## Goals / Non-Goals

**Goals:**

- Lower minimum deployment target to macOS 12.0 without removing any existing macOS 14+ functionality.
- Provide a working route-CRUD (add / edit / toggle / delete) experience on macOS 12–13 backed by Core Data.
- Keep SwiftData + `@Observable` as the sole persistence/reactive path on macOS 14+ (no code duplication on the happy path).
- System route view (read-only kernel table) retained on macOS 12+ using existing compatible SwiftUI APIs.
- Helper tool target also lowered to 12.0 (no functional change to helper code).

**Non-Goals:**

- Route group management on macOS 12–13 (groups rely on SwiftData `@Relationship`; omitted on legacy path).
- Supporting macOS 10.15 / 11 (require far larger SwiftUI API surface rewrites).
- Rewriting the UI layer to use AppKit/UIKit for older OS versions.
- Data sync or migration between the Core Data store (12–13) and SwiftData store (14+) when a user upgrades their OS mid-use (accept that on upgrade they start fresh or migrate manually via existing `CoreDataMigrator` logic).

## Decisions

### D1: Compile-time split via `#if canImport` + `@available` — not a protocol abstraction layer

**Decision**: Use `#available(macOS 14, *)` checks inline in existing files (and `#if canImport(SwiftData)` for import blocks) rather than creating a `PersistenceStack` protocol that both stacks implement.

**Rationale**: A protocol abstraction adds significant indirection and boilerplate for a two-variant codebase where the variants differ in fundamental type constraints (SwiftData `@Model` classes vs `NSManagedObject`). The `#available` approach keeps the SwiftData path unchanged and untouched on macOS 14+, which is the primary user target. The proposal listed `os-conditional-persistence` as a new capability, but a thin protocol would be over-engineering for this scope.

**Alternative considered**: Full protocol with `AnyPersistenceStack` type-erasure — rejected because it forces all call sites to lose type safety and adds ~300 lines of glue code for a path (macOS 12–13) that will shrink over time.

### D2: `RouterService` uses `ObservableObject` + `@Published` on macOS 12–13 via conditional compilation

**Decision**: `RouterService.swift` is split with `#if canImport(Observation)` (which maps to macOS 14+). On the legacy path, `RouterService` conforms to `ObservableObject` and `@Published` properties replace `@Observable` implicit observation.

**Rationale**: `@Observable` and `ObservableObject` are mutually exclusive conformances on a single class. Using `#if canImport(Observation)` (available since Swift 5.9 / Xcode 15) cleanly separates them at compile time without needing two separate files.

**Alternative considered**: Separate `RouterServiceLegacy` class — rejected because it requires duplicating all business logic (XPC calls, route activation, socket monitoring).

### D3: Environment injection via `@EnvironmentObject` on macOS 12–13, typed `@Environment` on 14+

**Decision**: All views that inject `RouterService` from the environment use `#available` to call `.environment(routerService)` (14+) or `.environmentObject(routerService)` (12–13) at the scene level, and `@Environment(RouterService.self)` (14+) vs `@EnvironmentObject var routerService: RouterService` (12–13) at the property level.

**Rationale**: Typed `@Environment` without a key path requires `@Observable` conformance (macOS 14+). `@EnvironmentObject` is the idiomatic macOS 12–13 equivalent and requires `ObservableObject`.

### D4: Views using `@Query` get a version-split wrapper approach

**Decision**: Views that drive their list from `@Query` (e.g., `RouteListView`, `SidebarView`, `SystemRouteTableView`) are split using `#available(macOS 14, *)` at the body level. On 14+ the existing `@Query` property is used; on 12–13 a `@FetchRequest` property (Core Data) drives the list instead.

**Rationale**: `@Query` is a property wrapper tied to SwiftData's model context — it cannot coexist in the same type with `@FetchRequest` without duplicate property declarations under `#if`. The clearest approach is a conditional body dispatch.

**Alternative considered**: Wrapping both in a generic `@StateObject` view model — adds significant boilerplate and obscures the data flow that SwiftUI tools (Instruments, Previews) expect.

### D5: Group management UI gated behind `#available(macOS 14, *)`

**Decision**: `GroupSheets.swift`, the group-assignment button/sheet in `RouteListView`, and group-related sidebar entries are wrapped in `if #available(macOS 14, *)` blocks. On older OS, those UI surfaces are simply not rendered.

**Rationale**: Route groups require SwiftData `@Relationship` and `PersistentIdentifier` — both macOS 14+ only. Reproducing this in Core Data is out of scope (see Non-Goals). The simpler degraded experience is correct for a feature the user confirmed is acceptable to omit on legacy.

### D6: Core Data model file (`StaticRouteHelper.xcdatamodeld`) reused/extended, not created from scratch

**Decision**: The existing `CoreDataMigrator.swift` reads from a pre-existing Core Data store (`StaticRouteHelperLegacy`). We extend that model (or create a parallel `StaticRouteLegacy.xcdatamodeld`) with `RouteRuleMO` entity matching the SwiftData `RouteRule` fields.

**Rationale**: The migration infrastructure already exists. Reusing it avoids a cold-start Core Data setup. The `RouteRuleMO` entity schema is a subset of the SwiftData `RouteRule` model (network, prefix, gateway, gatewayType, isActive, note, createdAt).

### D7: Two-argument `.onChange` replaced with `.onChange` + explicit `newValue` on 12–13

**Decision**: The four two-argument `.onChange(of: x) { old, new in }` closures in `RouteEditSheet.swift` are replaced using `#available(macOS 14, *)` — on older OS using `.onChange(of: x) { new in }` (single-arg, available since macOS 13) or `.onChange(of: x) { [self] in ... }` capture form for macOS 12.

**Note**: macOS 12 introduced `.onChange(of:perform:)` (single `newValue` trailing closure) which is sufficient for all four use cases here. No logic change required.

## Risks / Trade-offs

- **[Risk] OS upgrade data loss**: A user running on macOS 13 (Core Data) who upgrades to macOS 14 will have their routes in the Core Data store; the SwiftData store will be empty.  
  → **Mitigation**: Extend `CoreDataMigrator` to auto-run on first launch on macOS 14+ if the legacy Core Data store exists. This is the existing migration path, just triggered automatically.

- **[Risk] `#if canImport(Observation)` behaves differently than `#available`**: `canImport` is a compile-time check, while `#available` is runtime. If the SDK ships the Observation module even when targeting 12.0 (which it does in Xcode 15+), `#if canImport(Observation)` will always be true on all deployment targets, silently removing the legacy path.  
  → **Mitigation**: Use `#if swift(>=5.9) && canImport(Observation)` *combined* with `@available(macOS 14, *)` guards, or simply use `#if os(macOS)` — the canonical pattern is `if #available(macOS 14, *)` at *runtime* for branching behavior, and `@available(macOS 14, *)` on *declarations* that use macOS 14 APIs. For the `@Observable` class definition itself, a separate file `RouterService+Observable.swift` (available only when 14+) is the cleanest approach.  
  → **Revised decision**: Use two source files — `RouterService.swift` (base, `ObservableObject`) and `RouterService+Observation.swift` (`@available(macOS 14, *)` extension adding `@Observable` retroactively via a wrapper) — **or** use `@available(macOS 14, *)` on the entire class and a separate `RouterServiceLegacy: ObservableObject` for the 12–13 path injected conditionally. Final approach selected: **single file with `#if swift(>=5.9)` + `@available` attribute** on the `@Observable` line (compiler accepts this pattern in Xcode 15+).

- **[Risk] `@FetchRequest` in a view also requires `NSManagedObjectContext` in environment**: The legacy path needs `.environment(\.managedObjectContext, context)` injected at the scene level.  
  → **Mitigation**: Inject `NSManagedObjectContext` alongside SwiftData's model context in `StaticRouteHelperApp`, each behind their respective `#available` guards.

- **[Risk] Testing surface doubles**: Two persistence paths means bugs can exist on only one OS version.  
  → **Mitigation**: The macOS 14+ path remains unchanged (existing tests cover it). Core Data path on 12–13 should have integration tests added in a follow-up; for now, the simpler CRUD scope reduces risk.

- **[Risk] Xcode Previews break on older OS simulator targets**: Some `@Query`-based views will crash in previews if the preview target is set to macOS 12.  
  → **Mitigation**: Preview providers can be annotated `@available(macOS 14, *)` for SwiftData-backed previews; legacy views get their own preview with a mock `NSManagedObjectContext`.

## Migration Plan

1. Lower `MACOSX_DEPLOYMENT_TARGET` to `12.0` in Xcode project — do this first to surface all compiler errors.
2. Fix compiler errors file by file, starting with the most depended-on (`RouterService`, then models, then views).
3. Add `RouteRuleMO.swift` (NSManagedObject) + `LegacyPersistenceStack.swift` (NSPersistentContainer setup).
4. Add `LegacyRouteListView.swift` — a `@FetchRequest`-driven equivalent of the `@Query`-driven `RouteListView` for macOS 12–13.
5. Update `StaticRouteHelperApp.swift` to conditionally inject SwiftData vs Core Data environment.
6. Update all view files to add `#available` guards.
7. Extend `CoreDataMigrator` to auto-detect and migrate on first macOS 14+ launch.
8. Build and test on macOS 12 simulator, macOS 13 simulator, macOS 14+ device.

**Rollback**: Git revert. The deployment target change is fully reversible.

## Open Questions

- Should we ship to macOS 12 users with a "Limited Mode" banner informing them that group management requires macOS 14+? Or silently omit those features?
- Is the Core Data → SwiftData auto-migration on OS upgrade required for v1 of this backport, or can it be deferred to a follow-up?
- The helper tool's `MACOSX_DEPLOYMENT_TARGET` can be lowered independently — should it go to 12.0 or stay higher given it only runs as a system daemon?
