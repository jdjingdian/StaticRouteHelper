# Magicdian's static route helper

## Download & Installation

Pre-built binaries are available on the [GitHub Releases](../../releases) page.

Because this project is not signed with a paid Apple Developer certificate, the app is distributed with **ad-hoc code signing** and is **not notarized**. macOS Gatekeeper will block it from opening after download. To remove the restriction, run the following command in Terminal after unzipping:

```bash
xattr -cr /path/to/Static\ Router.app
```

Replace `/path/to/Static\ Router.app` with the actual path where you placed the app (e.g., `~/Applications/Static\ Router.app`). This command removes the `com.apple.quarantine` flag that Gatekeeper sets on downloaded files, allowing the app to launch normally.

## Notes

This is a helper tool for macOS written in Swift and SwiftUI. You can use it to manage macOS network route. It use `/sbin/route` to do the job, and it need root privileges. It gains root privileges with official API.

## Feature && TODO

- [x] show system routes
- [x] Add/Delete route
- [ ] **SMAppService** for macOS 13.0+
- [ ] Rewrite the UI
- [ ] Using Network Extension  to replace using `/sbin/route`
- [ ] Localization
- [ ] Dark Mode



License
-------

StaticRouteHelper is licensed under the [GPLv3](./LICENSE) license.  
Copyright &copy; 2021, Derek Jing

