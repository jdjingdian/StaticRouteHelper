## Why

The Helper daemon currently writes routes by spawning `/sbin/route` as a subprocess via `ProcessRunner.runCommand(wrapCmd:)`. This approach forks a process, parses string-based CLI arguments, and depends on an external binary — all unnecessary overhead given that the same kernel operation is directly reachable via a `PF_ROUTE` raw socket write. Eliminating the subprocess reduces latency, removes the `/sbin/route` binary dependency, and makes the Helper's behavior fully introspectable in code.

## What Changes

- **NEW**: `PFRouteWriter` — a Swift type in the `RouteHelper` target that opens a `PF_ROUTE` raw socket and sends `RTM_ADD` / `RTM_DELETE` `rt_msghdr` messages directly to the kernel to add or remove IPv4 routes.
- **REMOVED**: `ProcessRunner.runCommand(wrapCmd:)` — the XPC handler that spawned `/sbin/route` subprocesses is replaced by `PFRouteWriter`.
- **CHANGED**: `RouterCommandReply` — the XPC reply type (`terminationStatus`, `standardOutput`, `standardError`) is replaced by a leaner `RouteWriteReply` (`success: Bool`, `errorMessage: String?`) that reflects socket-level outcomes rather than subprocess exit codes.
- **CHANGED**: `RouterCommand` / `RouterCommandType` — the `.route` case and `BuildManageRouteCommand()` are replaced by a new `RouteWriteRequest` XPC message type carrying structured fields (`network`, `mask`, `gateway`, `gatewayType`, `add: Bool`) instead of raw CLI argument strings. **BREAKING** for the XPC protocol between the main app and Helper (both must be updated together).
- **REMOVED**: `RouterCommandType.route` / `launchPath` — no longer needed once the subprocess path is gone. `BuildPrintRouteCommand()` / `RouterCommandType.netstat` are already deprecated (v1.2) and remain untouched by this change.
- **CHANGED**: `RouterService.activateRoute(_:)` / `deactivateRoute(_:)` — updated to send `RouteWriteRequest` instead of `RouterCommand`; error mapping updated from `commandFailed(exitCode:stderr:)` to a socket-level error case.

## Capabilities

### New Capabilities
- `pf-route-writer`: Direct kernel route manipulation via `PF_ROUTE` socket write in the privileged Helper, replacing the `/sbin/route` subprocess path.

### Modified Capabilities
- `pf-route-reader`: The `pf-route-reader` spec is unaffected at the requirement level; `SystemRouteReader` remains unchanged. *(No delta spec needed.)*

## Impact

- **RouteHelper target**: `ProcessRunner.swift` — `runCommand(wrapCmd:)` replaced; `run_whoami()` and the debug XPC route can remain. New file `PFRouteWriter.swift` added.
- **Shared target**: `RouterCommand.swift` — `RouterCommandType.route`, `BuildManageRouteCommand()`, `BuildRouteArgs()` removed; new `RouteWriteRequest` and `RouteWriteReply` Codable types added. `RouterCommandReply` retained only if `run_whoami` / debug route still uses it.
- **StaticRouter target**: `RouterService.swift` — `sendCommand(_:)` / `sendCommandWithReply(_:)` updated; `RouterError.commandFailed` may need a new error case for socket write failures.
- **No UI changes** required; route activation/deactivation API surface (`activateRoute`, `deactivateRoute`) is unchanged from the caller's perspective.
- **XPC protocol version bump** required: Helper and main app must ship together; no backward compatibility with older Helper binaries.
