## Context

The `RouteHelper` privileged daemon (running as root via SMJobBless) currently handles route add/delete by spawning `/sbin/route` as a subprocess through `ProcessRunner.runCommand(wrapCmd:)`. The XPC message carries a `RouterCommand` (a `commandType` enum + raw CLI `commandArgs` string array), and the reply carries a `RouterCommandReply` (process exit code + stdout/stderr strings).

Meanwhile the read side already uses the `PF_ROUTE` socket directly (`SystemRouteReader`, `RouteMonitor`). The write side is the last remaining subprocess path.

Constraints:
- macOS: `write()` to a `PF_ROUTE` raw socket with `RTM_ADD`/`RTM_DELETE` requires the caller to be root (`EACCES` otherwise). The Helper already runs as root — this is exactly where the write belongs.
- The XPC transport (`SecureXPC`) serialises messages using `Codable`. Any new message type must be `Codable`.
- The Helper and main app ship together; breaking XPC protocol changes are acceptable as long as both sides are updated atomically.

## Goals / Non-Goals

**Goals:**
- Replace the `/sbin/route` subprocess path in `RouteHelper` with a direct `PF_ROUTE` socket write (`RTM_ADD` / `RTM_DELETE` `rt_msghdr` messages).
- Replace the CLI-string–based XPC message (`RouterCommand` with `commandArgs: [String]`) with a typed, structured `RouteWriteRequest` carrying semantic fields.
- Replace the subprocess-exit-code–based XPC reply (`RouterCommandReply`) with a lean `RouteWriteReply` (`success: Bool`, `errorMessage: String?`).
- Keep `RouterService.activateRoute` / `deactivateRoute` API surface unchanged for callers.
- Remove `ProcessRunner.runCommand(wrapCmd:)` and `RouterCommandType.route`.

**Non-Goals:**
- Removing `ProcessRunner.run_whoami()` or the debug XPC route (unrelated).
- Modifying the PF_ROUTE read path (`SystemRouteReader`, `RouteMonitor`) — already correct.
- Supporting IPv6 routes in this change.
- Changing the UI or SwiftData models.
- Handling the deprecated `BuildPrintRouteCommand` / `RouterCommandType.netstat` path.

## Decisions

### Decision 1: Structured `RouteWriteRequest` over passing raw `commandArgs`

**Choice**: Define a new `Codable` struct `RouteWriteRequest` with fields `network: String`, `mask: String`, `gateway: String`, `gatewayType: GatewayType`, `add: Bool`.

**Why**: Passing raw CLI strings (`["-net", "10.0.0.0", "-netmask", ...]`) through XPC to a root daemon is a command-injection risk surface. Structured fields allow the Helper to construct the kernel message without interpreting attacker-controlled string tokens. It also makes the intent self-documenting and testable without a subprocess.

**Alternative considered**: Keep `RouterCommand` and just swap the implementation inside `ProcessRunner`. Rejected because it perpetuates the string-argument interface and conflates the "what to do" (structured intent) with "how the old CLI was called".

### Decision 2: `PFRouteWriter` as a pure value-type namespace (`enum`) in `RouteHelper`

**Choice**: Implement `PFRouteWriter` as a caseless `enum` (Swift namespace pattern) with a single static function `write(request: RouteWriteRequest) throws`. It opens a `PF_ROUTE` socket, constructs `rt_msghdr` + `sockaddr_in` (destination, netmask, gateway), sends with `Darwin.write()`, and closes the socket.

**Why**: Mirrors the existing `ProcessRunner` structure so the XPC handler registration in `main.swift` changes minimally (`ProcessRunner.runCommand(wrapCmd:)` → `PFRouteWriter.write(request:)`). Stateless — no need to keep a socket open between calls; routes are added/deleted infrequently.

**Alternative considered**: Keep the socket open across calls. Rejected because the Helper process is long-lived and an idle open raw socket adds unnecessary kernel state. Infrequent route operations don't justify it.

### Decision 3: `RouteWriteReply` replaces `RouterCommandReply`

**Choice**: New `Codable` struct `RouteWriteReply { let success: Bool; let errorMessage: String? }`. The Helper maps `errno` → `errorMessage` string. The main app maps a non-success reply → `RouterError.routeWriteFailed(String)`.

**Why**: `RouterCommandReply` models subprocess stdout/stderr and a UNIX exit code — none of which exist in a socket write path. Carrying those fields would require faking them. A purpose-built reply is cleaner and avoids dead fields.

**Alternative considered**: Reuse `RouterCommandReply` with `terminationStatus = 0 / errno`, `standardError = strerror(errno)`. Rejected because it's semantically confusing (no process ran) and leaves dead fields (`standardOutput`) in the protocol.

### Decision 4: `rt_msghdr` construction approach — manual struct population

**Choice**: Populate an `rt_msghdr` + `sockaddr_in` layout in a stack-allocated `Data` buffer using Swift `UnsafeMutableRawPointer`, mirroring the approach already used in `SystemRouteReader` for the read path.

**Why**: The codebase already has an established pattern for working with PF_ROUTE kernel structures in Swift (see `RouterService.extractAddrsFromMessage`, `SystemRouteReader`). Consistency lowers the review burden.

**Address mask handling**: For gateway-type `.ipAddress`, include `RTA_DST | RTA_GATEWAY | RTA_NETMASK`. For gateway-type `.interface`, include `RTA_DST | RTA_NETMASK | RTA_IFP` (interface index via `if_nametoindex`).

### Decision 5: XPC route key stays at `SharedConstant.commandRoute`

**Choice**: Reuse the existing `commandRoute` XPC route key, changing only the message and reply types.

**Why**: Avoids bumping the XPC route name and simplifies the migration — both sides change together in one PR, no versioned route negotiation needed.

**Risk**: Old Helper + new app (or vice versa) will fail with a Codable decode error. Acceptable because Helper and app always ship together and the Helper version check (`helperToolVersion`) gates activation.

## Risks / Trade-offs

**[Risk] `rt_msghdr` field alignment / padding is architecture-specific** → Mitigation: Use `MemoryLayout<rt_msghdr>.size` and `MemoryLayout<sockaddr_in>.size` for offsets; write a unit-testable helper that validates the constructed buffer round-trips through `extractAddrsFromMessage` (already in `RouterService`).

**[Risk] `RTM_ADD` on an existing route returns `EEXIST` (errno 17); `RTM_DELETE` on a missing route returns `ESRCH` (errno 3)** → Mitigation: Map these specific errnos to informative `errorMessage` strings (e.g. "Route already exists", "Route not found") so `RouterError.routeWriteFailed` surfaces a readable message in the UI.

**[Risk] Interface-gateway routes require `if_nametoindex` which may fail for non-existent interfaces** → Mitigation: Return a `RouteWriteReply(success: false, errorMessage: "Interface not found: \(name)")` before attempting the socket write.

**[Risk] `RouterCommandReply` is still referenced by `run_whoami` debug route** → Mitigation: `run_whoami` returns `Void` (no reply); `RouterCommandReply` can be fully removed once `runCommand` is gone. The debug route is registered as a no-reply handler. Confirm before deleting the type.

## Migration Plan

1. Add `RouteWriteRequest` and `RouteWriteReply` to `Shared/RouterCommand.swift` (new types, additive).
2. Add `PFRouteWriter.swift` to `RouteHelper` target.
3. Update `main.swift` in `RouteHelper`: replace `server.registerRoute(SharedConstant.commandRoute, handler: ProcessRunner.runCommand(wrapCmd:))` with `server.registerRoute(SharedConstant.commandRoute, handler: PFRouteWriter.write(request:))`.
4. Update `RouterService.swift` in `StaticRouter`: update `sendCommand` / `sendCommandWithReply` to use `RouteWriteRequest` / `RouteWriteReply`; update `activateRoute` / `deactivateRoute`.
5. Add `RouterError.routeWriteFailed(String)` case; remove `RouterError.commandFailed`.
6. Remove `RouterCommandType.route`, `BuildManageRouteCommand()`, `BuildRouteArgs()` from `RouterCommand.swift`.
7. Remove `ProcessRunner.runCommand(wrapCmd:)` from `RouteHelper`.
8. Bump `helperToolVersion` in `SharedConstant` / property list to invalidate old Helper binaries.
9. Build and test: add a route via UI, verify it appears in `SystemRouteReader.readRoutes()`, delete it, verify it disappears. Confirm no `/sbin/route` process appears in Activity Monitor.

**Rollback**: Revert both targets together. The Helper version check prevents the new app from using an old Helper.

## Open Questions

- Should `RouteWriteRequest.gatewayType` use the existing `RouterCommand.GatewayType` enum (moving it to the shared `RouteWriteRequest` type), or define a new identical enum? Preference: move/rename to avoid duplication since `BuildManageRouteCommand` (the only other user) is being deleted.
- Does the debug `commandRoute` usage in `run_whoami` actually use the reply? Confirm `run_whoami` is registered as a no-reply route before deleting `RouterCommandReply`.
