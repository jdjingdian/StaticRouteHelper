## 1. project.pbxproj — Add CURRENT_PROJECT_VERSION to Both Targets

- [x] 1.1 In the `RouteHelper` target's **Debug** build configuration in `project.pbxproj`, add `CURRENT_PROJECT_VERSION = 1.3.1;`
- [x] 1.2 In the `RouteHelper` target's **Release** build configuration in `project.pbxproj`, add `CURRENT_PROJECT_VERSION = 1.3.1;`
- [x] 1.3 In the `Static Router` target's **Debug** build configuration in `project.pbxproj`, set `CURRENT_PROJECT_VERSION = 1.3.1;` and `MARKETING_VERSION = 1.3.1;`
- [x] 1.4 In the `Static Router` target's **Release** build configuration in `project.pbxproj`, set `CURRENT_PROJECT_VERSION = 1.3.1;` and `MARKETING_VERSION = 1.3.1;`

## 2. RouteHelper/Info.plist — Replace Hardcoded Version

- [x] 2.1 In `RouteHelper/Info.plist`, change the `CFBundleVersion` value from the hardcoded literal (`1.3.0`) to `$(CURRENT_PROJECT_VERSION)`

## 3. StaticRouter/Info.plist — Replace Hardcoded CFBundleVersion

- [x] 3.1 In `StaticRouter/Info.plist`, change the `CFBundleVersion` value from the hardcoded literal (`1`) to `$(CURRENT_PROJECT_VERSION)`

## 4. Build Verification

- [x] 4.1 Build the `RouteHelper` target; confirm it compiles without errors
- [x] 4.2 Verify that the built `RouteHelper` binary's embedded `__info_plist` segment contains the resolved value `1.3.1` — run: `strings <path-to-built-RouteHelper> | grep '1\.3\.1'` or `otool -s __TEXT __info_plist <path-to-built-RouteHelper>`
- [x] 4.3 If step 4.2 shows the unexpanded string `$(CURRENT_PROJECT_VERSION)` instead of `1.3.1`: switch `RouteHelper/Info.plist` to be processed via `INFOPLIST_FILE` (remove the manual `-sectcreate __TEXT __info_plist` flag from `OTHER_LDFLAGS` and let Xcode embed it automatically); rebuild and re-verify
- [x] 4.4 Build the `Static Router` target; confirm it compiles without errors
- [ ] 4.5 Confirm the About panel displays version `1.3.1` when the app is run

## 5. On-Device Verification

- [ ] 5.1 Install the new Helper via the app's Settings UI; confirm the version upgrade prompt appears if an older (`1.3.0`) Helper is already installed
- [ ] 5.2 After installation, confirm Settings shows Helper as `.installed` (green checkmark, no upgrade prompt)
