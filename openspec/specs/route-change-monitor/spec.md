## ADDED Requirements

### Requirement: RouterService runs a persistent PF_ROUTE socket listener
The system SHALL maintain a background `Task` within `RouterService` that continuously reads from a `PF_ROUTE` raw socket, processing `RTM_ADD` and `RTM_DELETE` kernel messages for the lifetime of the application.

#### Scenario: Listener starts on RouterService initialization
- **WHEN** `RouterService` is initialized
- **THEN** a background `Task` is started that opens a `PF_ROUTE` socket and enters a blocking read loop awaiting route change messages

#### Scenario: Listener is cancelled when RouterService is deallocated
- **WHEN** `RouterService.deinit` is called (app exits)
- **THEN** the monitoring `Task` is cancelled and the PF_ROUTE socket is closed, with no resource leak

#### Scenario: Non-IPv4 messages are ignored without crashing
- **WHEN** the PF_ROUTE socket receives a message with address family other than `AF_INET` (e.g. `AF_INET6`, `AF_LINK`)
- **THEN** the message is silently skipped and the loop continues

### Requirement: RTM_DELETE events set isActive to false for matching RouteRules
The system SHALL respond to `RTM_DELETE` messages by finding any `RouteRule` whose `network` matches the deleted route's destination (after normalization) and whose `gateway` matches, and setting that rule's `isActive` to `false` in SwiftData.

#### Scenario: Matching rule is deactivated on RTM_DELETE
- **WHEN** the OS sends an `RTM_DELETE` message for destination `"10.8.0.0"` / gateway `"192.168.1.1"`
- **THEN** the `RouteRule` with `network == "10.8.0.0"` and `gateway == "192.168.1.1"` has `isActive` set to `false`

#### Scenario: Unmatched RTM_DELETE does not modify any RouteRule
- **WHEN** the OS sends an `RTM_DELETE` message for a route that does not match any stored `RouteRule`
- **THEN** no `RouteRule.isActive` values are changed; `systemRoutes` snapshot is updated

#### Scenario: isActive update is performed on MainActor
- **WHEN** a matching `RTM_DELETE` is received on the background thread
- **THEN** the SwiftData `ModelContext` write is performed inside `await MainActor.run { }` to satisfy `@MainActor` isolation requirements

### Requirement: RTM_ADD events set isActive to true for matching RouteRules
The system SHALL respond to `RTM_ADD` messages by finding any `RouteRule` whose `network` matches the added route's destination (after normalization) and whose `gateway` matches, and setting that rule's `isActive` to `true` in SwiftData.

#### Scenario: Matching rule is activated on RTM_ADD
- **WHEN** the OS sends an `RTM_ADD` message for destination `"10.8.0.0"` / gateway `"192.168.1.1"`
- **THEN** the `RouteRule` with `network == "10.8.0.0"` and `gateway == "192.168.1.1"` has `isActive` set to `true`

#### Scenario: Unmatched RTM_ADD updates systemRoutes snapshot only
- **WHEN** the OS sends an `RTM_ADD` message for a route with no matching `RouteRule`
- **THEN** the `systemRoutes` array is refreshed to include the new entry, but no `RouteRule.isActive` is changed

### Requirement: isActive semantics reflect current system reality
The system SHALL treat `isActive` as a read-only reflection of the kernel route table state, NOT as user intent. The monitor SHALL NOT automatically re-add routes that are removed by the OS.

#### Scenario: VPN-induced route deletion sets isActive false and stays false
- **WHEN** a VPN connection deletes a managed route and triggers `RTM_DELETE`
- **THEN** the matching `RouteRule.isActive` is set to `false` and remains `false` until the user manually re-activates it via the UI

#### Scenario: No auto-reactivation occurs after RTM_DELETE
- **WHEN** `isActive` is set to `false` by an `RTM_DELETE` event
- **THEN** `RouterService` does NOT issue any XPC command to the Helper to re-add the route

### Requirement: High-frequency network events do not cause excessive SwiftData writes
The system SHALL filter PF_ROUTE events so that SwiftData writes are triggered only for events whose destination+gateway pair matches a stored `RouteRule`; all other events SHALL only refresh the in-memory `systemRoutes` snapshot.

#### Scenario: Default route changes during network switch do not write SwiftData
- **WHEN** the OS emits multiple `RTM_DELETE`/`RTM_ADD` events for default routes (`0.0.0.0`) during a network interface change
- **THEN** no SwiftData writes occur because no `RouteRule` has `network == "0.0.0.0"` as a managed route

#### Scenario: Only matching events trigger SwiftData persistence
- **WHEN** ten consecutive `RTM_DELETE` messages arrive, one of which matches a stored `RouteRule`
- **THEN** exactly one SwiftData write occurs (for the matching rule), and the other nine are processed without writing
