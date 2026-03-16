## ADDED Requirements

### Requirement: SystemRouteReader reads current route table via PF_ROUTE socket
The system SHALL provide a `SystemRouteReader` type that opens a `PF_ROUTE` raw socket and uses `sysctl(NET_RT_DUMP)` to obtain a full snapshot of the kernel IPv4 route table, returning a list of `SystemRouteEntry` values without requiring root privileges.

#### Scenario: Successful route table snapshot
- **WHEN** `SystemRouteReader.readRoutes()` is called
- **THEN** it returns an array of `SystemRouteEntry` values representing the current kernel IPv4 route table, with each entry populated from `rt_msghdr` + `sockaddr` kernel structures

#### Scenario: Entry fields are correctly mapped
- **WHEN** a route entry is parsed from the kernel message
- **THEN** `SystemRouteEntry.destination` contains the normalized dotted-decimal destination (e.g. `"192.168.3.0"` not `"192.168.3"`), `gateway` contains the next-hop address or interface name, `flags` reflects the `rtm_flags` bitmask, and `networkInterface` reflects the interface index resolved to a name

#### Scenario: Socket open failure is handled gracefully
- **WHEN** the PF_ROUTE socket cannot be opened (e.g. resource limit)
- **THEN** `readRoutes()` returns an empty array and logs a diagnostic error; it does NOT crash or throw an unhandled exception

#### Scenario: Loopback and link-scoped entries are included
- **WHEN** the kernel route table contains loopback (`127.0.0.1`) and link-scoped routes
- **THEN** they are included in the returned array so callers can filter as needed

### Requirement: RouterService uses SystemRouteReader instead of netstat
The system SHALL replace all usage of `parseNetstatOutput()` / `BuildPrintRouteCommand()` in `RouterService.refreshSystemRoutes()` with a call to `SystemRouteReader.readRoutes()`.

#### Scenario: refreshSystemRoutes fetches via PF_ROUTE
- **WHEN** `RouterService.refreshSystemRoutes()` is called
- **THEN** it invokes `SystemRouteReader.readRoutes()` to populate `systemRoutes`, and does NOT spawn a `netstat` subprocess

#### Scenario: BuildPrintRouteCommand is deprecated
- **WHEN** `Shared/RouterCommand.swift` is compiled
- **THEN** `BuildPrintRouteCommand()` is marked `@available(*, deprecated)` with a message directing to `SystemRouteReader`, so the compiler emits a warning if it is still called

### Requirement: RouteStateCalibrator normalizes destinations before comparison
The system SHALL normalize destination strings (appending `.0` to dotted-decimal addresses missing a final octet, e.g. `"192.168.3"` → `"192.168.3.0"`) before comparing a route table entry's destination to a `RouteRule`'s network field.

#### Scenario: Short-form destination matches full-form rule network
- **WHEN** the kernel route table contains destination `"192.168.3"` and a `RouteRule` has `network == "192.168.3.0"`
- **THEN** `RouteStateCalibrator` treats them as matching and sets `isActive = true`

#### Scenario: Already normalized destination is unchanged
- **WHEN** the kernel route table contains destination `"10.0.0.0"`
- **THEN** normalization returns `"10.0.0.0"` unchanged

#### Scenario: normalizeDestination is shared with SystemRouteTableView
- **WHEN** `SystemRouteTableView`'s existing `normalizeDestination()` helper is extracted into a shared location
- **THEN** both `RouteStateCalibrator` and `SystemRouteTableView` call the same implementation with no code duplication

### Requirement: All existing UI strings are migrated to Localizable.strings
The system SHALL contain no hardcoded user-visible strings in Swift source files; all UI strings SHALL be expressed via `String(localized: "semantic.key")` or `LocalizedStringKey` implicit conversion, with matching entries in both `en.lproj/Localizable.strings` and `zh-Hans.lproj/Localizable.strings`.

#### Scenario: English localization file has all keys
- **WHEN** the app is run with English locale
- **THEN** every UI label, button title, placeholder, and error message is drawn from `en.lproj/Localizable.strings` with no missing-translation fallback visible

#### Scenario: Simplified Chinese localization file has all keys
- **WHEN** the app is run with Simplified Chinese locale
- **THEN** every UI label, button title, placeholder, and error message is drawn from `zh-Hans.lproj/Localizable.strings` with no missing-translation fallback visible

#### Scenario: Semantic keys follow naming convention
- **WHEN** new localization keys are added
- **THEN** they follow the `"<view>.<element>.<property>"` dot-notation pattern (e.g. `"route.list.empty.title"`, `"settings.general.helper.install.button"`)

#### Scenario: No NSLocalizedString usage is introduced
- **WHEN** the Swift source files are scanned for localization API usage
- **THEN** zero occurrences of `NSLocalizedString` are found; all calls use `String(localized:)` or `LocalizedStringKey`
