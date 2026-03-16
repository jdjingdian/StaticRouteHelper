## ADDED Requirements

### Requirement: PFRouteWriter sends RTM_ADD and RTM_DELETE messages via PF_ROUTE socket
The system SHALL provide a `PFRouteWriter` type in the `RouteHelper` target that, when given a `RouteWriteRequest`, opens a `PF_ROUTE` raw socket, constructs an `rt_msghdr` message with the appropriate `sockaddr_in` address buffers, writes the message to the kernel, closes the socket, and returns a `RouteWriteReply` indicating success or the specific error.

#### Scenario: Successful route addition
- **WHEN** `PFRouteWriter.write(request:)` is called with `add: true`, a valid IPv4 network, mask, and gateway IP address
- **THEN** the kernel IPv4 route table contains the new entry and the function returns `RouteWriteReply(success: true, errorMessage: nil)`

#### Scenario: Successful route deletion
- **WHEN** `PFRouteWriter.write(request:)` is called with `add: false` for a route that exists in the kernel table
- **THEN** the kernel IPv4 route table no longer contains the entry and the function returns `RouteWriteReply(success: true, errorMessage: nil)`

#### Scenario: Route already exists on add
- **WHEN** `PFRouteWriter.write(request:)` is called with `add: true` for a route that already exists (`errno == EEXIST`)
- **THEN** the function returns `RouteWriteReply(success: false, errorMessage: "Route already exists")`

#### Scenario: Route not found on delete
- **WHEN** `PFRouteWriter.write(request:)` is called with `add: false` for a route that does not exist (`errno == ESRCH`)
- **THEN** the function returns `RouteWriteReply(success: false, errorMessage: "Route not found")`

#### Scenario: Socket open failure is surfaced
- **WHEN** the `PF_ROUTE` socket cannot be opened (e.g. `errno == EMFILE`)
- **THEN** the function returns `RouteWriteReply(success: false, errorMessage: "Failed to open PF_ROUTE socket: <errno string>")` and does NOT crash

#### Scenario: Interface-gateway route uses if_nametoindex
- **WHEN** `PFRouteWriter.write(request:)` is called with `gatewayType == .interface` and a valid interface name
- **THEN** the `rt_msghdr` message contains `RTA_IFP` set to the resolved interface index and the route is installed via the named interface

#### Scenario: Interface not found returns error
- **WHEN** `PFRouteWriter.write(request:)` is called with `gatewayType == .interface` and an interface name for which `if_nametoindex` returns 0
- **THEN** the function returns `RouteWriteReply(success: false, errorMessage: "Interface not found: <name>")` without attempting the socket write

### Requirement: RouteWriteRequest is a typed Codable XPC message replacing RouterCommand for write operations
The system SHALL define a `RouteWriteRequest` struct conforming to `Codable` with fields `network: String`, `mask: String`, `gateway: String`, `gatewayType: GatewayType`, `add: Bool`. `GatewayType` SHALL be a `Codable` enum with cases `ipAddress` and `interface`. `RouterCommand.BuildManageRouteCommand()`, `RouterCommand.BuildRouteArgs()`, and `RouterCommandType.route` SHALL be removed.

#### Scenario: RouteWriteRequest encodes and decodes correctly
- **WHEN** a `RouteWriteRequest` value is encoded to JSON (or the SecureXPC wire format) and decoded back
- **THEN** all fields (`network`, `mask`, `gateway`, `gatewayType`, `add`) round-trip with identical values

#### Scenario: RouterCommandType.route is removed
- **WHEN** `Shared/RouterCommand.swift` is compiled
- **THEN** `RouterCommandType.route` and `RouterCommandType.launchPath` (returning `/sbin/route`) do NOT exist; the compiler produces no reference to `/sbin/route`

### Requirement: RouteWriteReply is a typed Codable XPC reply replacing RouterCommandReply for write operations
The system SHALL define a `RouteWriteReply` struct conforming to `Codable` with fields `success: Bool` and `errorMessage: String?`. `RouterCommandReply` (with `terminationStatus`, `standardOutput`, `standardError`) SHALL be removed once no route in `main.swift` references it.

#### Scenario: Successful reply carries no error message
- **WHEN** `PFRouteWriter.write(request:)` succeeds
- **THEN** the returned `RouteWriteReply` has `success == true` and `errorMessage == nil`

#### Scenario: Failure reply carries descriptive error message
- **WHEN** `PFRouteWriter.write(request:)` fails
- **THEN** the returned `RouteWriteReply` has `success == false` and `errorMessage` contains a non-empty human-readable description of the failure

### Requirement: RouteHelper XPC handler uses PFRouteWriter instead of ProcessRunner.runCommand
The system SHALL register `PFRouteWriter.write(request:)` as the handler for `SharedConstant.commandRoute` in `RouteHelper/main.swift`, replacing `ProcessRunner.runCommand(wrapCmd:)`. `ProcessRunner.runCommand(wrapCmd:)` SHALL be removed.

#### Scenario: XPC command route calls PFRouteWriter
- **WHEN** the `RouteHelper` daemon receives an XPC message on `SharedConstant.commandRoute` with a `RouteWriteRequest` payload
- **THEN** it calls `PFRouteWriter.write(request:)` and returns the resulting `RouteWriteReply` to the caller; no `/sbin/route` subprocess is spawned

#### Scenario: No subprocess is created for route operations
- **WHEN** a route add or delete is triggered via the main app
- **THEN** no `Process()` instance is created and no child process with path `/sbin/route` appears in the process tree

### Requirement: RouterService sends RouteWriteRequest and maps RouteWriteReply to RouterError
The system SHALL update `RouterService.activateRoute(_:)` and `deactivateRoute(_:)` to send a `RouteWriteRequest` via XPC and interpret a `RouteWriteReply`. A `reply.success == false` SHALL throw `RouterError.routeWriteFailed(String)` with the `errorMessage` from the reply. `RouterError.commandFailed(exitCode:stderr:)` SHALL be removed.

#### Scenario: activateRoute sends a RouteWriteRequest
- **WHEN** `RouterService.activateRoute(_:)` is called with a valid `RouteRule`
- **THEN** it sends a `RouteWriteRequest` with `add: true` and the rule's `network`, `subnetMask`, `gateway`, and `gatewayType` fields via XPC; it does NOT send a `RouterCommand`

#### Scenario: deactivateRoute sends a RouteWriteRequest
- **WHEN** `RouterService.deactivateRoute(_:)` is called with a valid `RouteRule`
- **THEN** it sends a `RouteWriteRequest` with `add: false` and the rule's fields via XPC; it does NOT send a `RouterCommand`

#### Scenario: Failed reply surfaces RouterError.routeWriteFailed
- **WHEN** the XPC reply contains `RouteWriteReply(success: false, errorMessage: "Route already exists")`
- **THEN** `RouterService` throws `RouterError.routeWriteFailed("Route already exists")` and the error is surfaced to the UI via `lastError`

### Requirement: Helper tool version is bumped to invalidate stale Helper binaries
The system SHALL increment the `helperToolVersion` in `SharedConstant` (and the corresponding Info.plist / launchd plist `CFBundleVersion`) so that a Helper binary built before this change is detected as outdated and the main app prompts for reinstallation.

#### Scenario: Old Helper is detected as needing upgrade
- **WHEN** the main app runs with a Helper binary whose version is less than the new `helperToolVersion`
- **THEN** `RouterService.helperStatus` equals `.needUpgrade` and the UI prompts the user to reinstall the Helper
