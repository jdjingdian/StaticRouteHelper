## 1. Shared Layer — New XPC Message Types

- [x] 1.1 Add `GatewayType` Codable enum (`ipAddress`, `interface`) to `Shared/RouterCommand.swift`, replacing the existing `RouterCommand.GatewayType` nested enum
- [x] 1.2 Add `RouteWriteRequest: Codable` struct with fields `network: String`, `mask: String`, `gateway: String`, `gatewayType: GatewayType`, `add: Bool` to `Shared/RouterCommand.swift`
- [x] 1.3 Add `RouteWriteReply: Codable` struct with fields `success: Bool`, `errorMessage: String?` to `Shared/RouterCommand.swift`
- [x] 1.4 Remove `RouterCommandType.route` case and its `launchPath` returning `/sbin/route` from `RouterCommand.swift`
- [x] 1.5 Remove `RouterCommand.BuildManageRouteCommand()` and `RouterCommand.BuildRouteArgs()` static functions from `RouterCommand.swift`
- [x] 1.6 Verify `RouterCommandReply` is no longer referenced by any live (non-deprecated) code path; remove it from `RouterCommand.swift`

## 2. RouteHelper — PFRouteWriter Implementation

- [x] 2.1 Create `RouteHelper/PFRouteWriter.swift` as a caseless enum namespace
- [x] 2.2 Implement `PFRouteWriter.write(request: RouteWriteRequest) -> RouteWriteReply`: open a `PF_ROUTE` raw socket (`socket(PF_ROUTE, SOCK_RAW, AF_UNSPEC)`); return failure reply on `sock < 0`
- [x] 2.3 Implement IPv4-gateway path: construct `rt_msghdr` + `sockaddr_in` (destination, netmask, gateway) buffer with `rtm_addrs = RTA_DST | RTA_GATEWAY | RTA_NETMASK`; set `rtm_type = RTM_ADD` or `RTM_DELETE`, `rtm_flags = RTF_UP | RTF_GATEWAY | RTF_STATIC`, `rtm_version = RTM_VERSION`, `rtm_seq` (monotonic counter); write buffer to socket
- [x] 2.4 Implement interface-gateway path: call `if_nametoindex(gateway)` and return `RouteWriteReply(success: false, errorMessage: "Interface not found: \(name)")` if result is 0; otherwise construct `rt_msghdr` + `sockaddr_in` (destination, netmask) + `sockaddr_dl` (interface index) with `rtm_addrs = RTA_DST | RTA_NETMASK | RTA_IFP`
- [x] 2.5 Map `write()` return value: on success (`n >= 0`) return `RouteWriteReply(success: true, errorMessage: nil)`; on `EEXIST` return `"Route already exists"`; on `ESRCH` return `"Route not found"`; on any other `errno` return `"Route operation failed: \(String(cString: strerror(errno)))"`
- [x] 2.6 Ensure the `PF_ROUTE` socket is always closed (`defer { close(sock) }`) regardless of write outcome

## 3. RouteHelper — XPC Handler Update

- [x] 3.1 In `RouteHelper/main.swift`, replace `server.registerRoute(SharedConstant.commandRoute, handler: ProcessRunner.runCommand(wrapCmd:))` with `server.registerRoute(SharedConstant.commandRoute, handler: PFRouteWriter.write(request:))`
- [x] 3.2 Remove `ProcessRunner.runCommand(wrapCmd:)` from `RouteHelper/ProcessRunner.swift`
- [x] 3.3 Verify `ProcessRunner.run_whoami()` still compiles and its debug XPC route registration remains intact
- [x] 3.4 Verify `RouteHelper` target builds without errors or warnings related to removed types

## 4. StaticRouter — RouterService Update

- [x] 4.1 Add `RouterError.routeWriteFailed(String)` case with a localized description (`"路由操作失败：\(message)"`) to `RouterService.swift`
- [x] 4.2 Remove `RouterError.commandFailed(exitCode:stderr:)` case from `RouterService.swift`
- [x] 4.3 Update `RouterService.sendCommandWithReply(_:)` signature to send `RouteWriteRequest` and receive `RouteWriteReply` via XPC
- [x] 4.4 Update `RouterService.sendCommand(_:)` to map `RouteWriteReply.success == false` → throw `RouterError.routeWriteFailed(reply.errorMessage ?? "Unknown error")`
- [x] 4.5 Update `RouterService.activateRoute(_:)` to construct and send a `RouteWriteRequest(network:mask:gateway:gatewayType:add:true)` instead of `RouterCommand.BuildManageRouteCommand`
- [x] 4.6 Update `RouterService.deactivateRoute(_:)` to construct and send a `RouteWriteRequest` with `add: false` instead of `RouterCommand.BuildManageRouteCommand`
- [x] 4.7 Verify `StaticRouter` target builds without errors or warnings related to removed types

## 5. Version Bump

- [x] 5.1 Increment `helperToolVersion` in `SharedConstant.swift` (or the source of truth for the Helper version constant) to the next appropriate value (e.g. bump minor version)
- [x] 5.2 Update the `CFBundleVersion` in the Helper's `Info.plist` to match the new version
- [x] 5.3 Update the `CFBundleVersion` in the Helper's launchd property list if it carries a version field
- [x] 5.4 Verify that running the new app against an old Helper binary causes `RouterService.helperStatus` to equal `.needUpgrade`

## 6. Build and End-to-End Verification

- [x] 6.1 Build both `RouteHelper` and `StaticRouter` targets; resolve any compiler errors
- [ ] 6.2 Install the new Helper via the app's Settings UI
- [ ] 6.3 Add a test static route via the UI; verify the route appears in `SystemRouteReader.readRoutes()` and in the system route table (`netstat -nr`)
- [ ] 6.4 Delete the test route via the UI; verify it is removed from the system route table
- [ ] 6.5 Confirm no `/sbin/route` child process appears during add/delete operations (check via Activity Monitor or `ps`)
- [ ] 6.6 Trigger a duplicate-add scenario; confirm the UI surfaces a "Route already exists" error message
- [ ] 6.7 Trigger a delete-nonexistent scenario; confirm the UI surfaces a "Route not found" error message
