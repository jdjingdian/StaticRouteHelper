## 1. Foundation — Shared Utilities

- [x] 1.1 Extract `normalizeDestination()` from `SystemRouteTableView` into a shared location (e.g. a free function in a new `RouteUtils.swift` or an extension on `String`) so both `RouteStateCalibrator` and `SystemRouteTableView` can call the same implementation
- [x] 1.2 Update `SystemRouteTableView` to call the extracted `normalizeDestination()` instead of its local copy, and verify no behavioral change
- [x] 1.3 Update `RouteStateCalibrator` to call `normalizeDestination()` before comparing `entry.destination` to `rule.network`, fixing the short-form destination bug

## 2. SystemRouteReader — PF_ROUTE Snapshot

- [x] 2.1 Create `StaticRouter/Services/SystemRouteReader.swift` with a `SystemRouteReader` struct/enum containing a `readRoutes() -> [SystemRouteEntry]` method
- [x] 2.2 Implement `sysctl(NET_RT_DUMP)` call to obtain the raw route table buffer from the kernel
- [x] 2.3 Implement `rt_msghdr` + `sockaddr` parsing loop: iterate the buffer, read each `rt_msghdr`, extract destination and gateway `sockaddr_in` using the `rtm_addrs` bitmask, and map to `SystemRouteEntry`
- [x] 2.4 Ensure destination strings are normalized (full dotted-decimal, e.g. `"192.168.3.0"`) during parsing
- [x] 2.5 Add error handling: if `socket()` or `sysctl()` fails, log diagnostics and return `[]` without crashing
- [x] 2.6 Mark `BuildPrintRouteCommand()` in `Shared/RouterCommand.swift` as `@available(*, deprecated, message: "Use SystemRouteReader.readRoutes() instead")`

## 3. RouterService — Switch to PF_ROUTE Snapshot

- [x] 3.1 Update `RouterService.refreshSystemRoutes()` to call `SystemRouteReader.readRoutes()` instead of spawning a `netstat` subprocess
- [x] 3.2 Remove (or guard behind the deprecated path) the `parseNetstatOutput()` method from `RouterService`
- [x] 3.3 Verify `RouteStateCalibrator` is invoked correctly after the new snapshot is fetched and that `isActive` is set properly on app launch

## 4. Route Change Monitor — PF_ROUTE Listener

- [x] 4.1 Add a `monitoringTask: Task<Void, Never>?` property to `RouterService` to hold the background listener
- [x] 4.2 Implement the listener loop: open `socket(PF_ROUTE, SOCK_RAW, AF_UNSPEC)`, enter a blocking `read()` loop inside a Swift `Task`, and cancel/close on task cancellation
- [x] 4.3 Implement `RTM_DELETE` message handling: parse destination + gateway from the message, find a matching `RouteRule` (using normalized destination), and set `isActive = false` via `await MainActor.run { }`
- [x] 4.4 Implement `RTM_ADD` message handling: parse destination + gateway, find a matching `RouteRule`, and set `isActive = true` via `await MainActor.run { }`; for non-matching events, refresh `systemRoutes` only
- [x] 4.5 Add the non-IPv4 message filter: skip messages whose address family is not `AF_INET`
- [x] 4.6 Add the noise filter: only trigger SwiftData writes when destination+gateway matches a stored `RouteRule`; all other events only refresh the in-memory `systemRoutes` snapshot
- [x] 4.7 Start the monitoring task in `RouterService.init` and cancel it in `RouterService.deinit`
- [x] 4.8 Verify that when a VPN removes a managed route, `isActive` is set to `false` and no automatic XPC re-add command is issued

## 5. Localization — Extraction and Keys

- [x] 5.1 Audit all Swift view files for hardcoded user-visible strings: `MainWindow.swift`, `RouteListView.swift`, `SidebarView.swift`, `RouteEditSheet.swift`, `SystemRouteTableView.swift`, `GroupSheets.swift`, `GeneralSettingsView.swift`, `GeneralSettings_HelperStateView.swift`, `AboutView.swift`, `CoreDataMigrator.swift`, `StaticRouteHelperApp.swift`
- [x] 5.2 Define semantic localization keys following the `"<view>.<element>.<property>"` pattern and add all entries to `en.lproj/Localizable.strings`
- [x] 5.3 Add Simplified Chinese translations for all new keys to `zh-Hans.lproj/Localizable.strings`
- [x] 5.4 Replace all hardcoded strings in the view files with `String(localized: "key")` or `LocalizedStringKey` implicit conversion; ensure zero `NSLocalizedString` calls are introduced
- [ ] 5.5 Verify no missing-translation fallbacks appear when running the app under both `en` and `zh-Hans` locales

## 6. Version Bump and Cleanup

- [x] 6.1 Change `MARKETING_VERSION` in `StaticRouter/Info.plist` (or `project.pbxproj`) from `1.1.0` to `1.2.0`
- [ ] 6.2 Build the project and confirm zero compiler errors and zero new warnings (deprecated `BuildPrintRouteCommand` warnings are expected and acceptable)
- [ ] 6.3 Run a quick manual smoke test: launch app, confirm routes load via PF_ROUTE, add/delete a route externally via `sudo route`, confirm `isActive` updates automatically
