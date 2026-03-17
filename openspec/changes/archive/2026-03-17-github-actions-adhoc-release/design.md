## Context

The project is a macOS SwiftUI application (`StaticRouteHelper.xcodeproj`) that manages static network routes. Currently there is no CI/CD pipeline — releases must be built and distributed manually by the developer.

Apple's distribution model normally requires a paid Developer ID certificate for notarized, Gatekeeper-trusted apps. Because this is a personal open-source project, the developer does not have a paid Apple developer certificate. Without notarization, macOS Gatekeeper will block the downloaded binary on first launch. The workaround is ad-hoc code signing and requiring users to manually remove the quarantine attribute via `xattr`.

## Goals / Non-Goals

**Goals:**
- Automate the build and packaging of the macOS app on every GitHub Release publish event
- Sign the binary with ad-hoc signing so macOS accepts it as minimally valid
- Attach the packaged `.zip` to the GitHub Release as a downloadable asset
- Document the Gatekeeper bypass procedure for users in both English (`README.md`) and Chinese (`README_CN.md`)

**Non-Goals:**
- Apple notarization (requires paid Developer ID certificate)
- TestFlight or App Store distribution
- Code signing with a real certificate
- Cross-platform builds
- Automated testing in CI (out of scope for this change)

## Decisions

### D1: Trigger on `release: published`

Use the `on: release: types: [published]` GitHub Actions trigger. This fires only when a Release is explicitly published (not drafted), ensuring the workflow runs at the right moment and the artifact is automatically attached to the correct release.

*Alternative considered*: Trigger on tag push (`on: push: tags`). Rejected because it requires a separate step to look up or create the release; the `release` event gives direct access to the upload URL.

### D2: Use `macos-latest` GitHub-hosted runner

GitHub provides free macOS runners with `xcodebuild` pre-installed. The `macos-latest` image currently maps to macOS 14 (Sonoma) or later, which satisfies the project's `MACOSX_DEPLOYMENT_TARGET = 15.0`.

*Alternative considered*: Self-hosted runner. Rejected because it requires infrastructure maintenance; GitHub-hosted runners are zero-maintenance for open-source projects.

### D3: Ad-hoc signing via `codesign`

Run `codesign --force --deep --sign -` on the built `.app` bundle. The `-` identity means "ad-hoc" — the binary is signed with a hash of itself rather than a certificate. This satisfies the macOS requirement that all executables be signed on Apple Silicon, while requiring no certificate.

*Alternative considered*: Ship unsigned binary. Rejected because unsigned binaries fail to run on Apple Silicon without additional SIP changes.

### D4: Package as `.zip` with `ditto`

Use `ditto -c -k --keepParent` to create a well-formed `.zip` that preserves macOS resource forks and extended attributes. This is the recommended approach for distributing `.app` bundles on macOS.

*Alternative considered*: `zip -r`. Rejected because it does not preserve macOS metadata correctly.

### D5: Upload via `gh` CLI (or `softprops/action-gh-release`)

Use the `actions/upload-release-asset` action (or the newer `softprops/action-gh-release`) to attach the `.zip` to the triggering release. The release upload URL is available directly from the `github.event.release.upload_url` context variable.

### D6: User Gatekeeper bypass via `xattr -cr`

Since the app is ad-hoc signed but not notarized, macOS Gatekeeper will quarantine it on download. Users must run:
```
xattr -cr /path/to/StaticRouteHelper.app
```
This removes the `com.apple.quarantine` extended attribute. This is a well-known, safe procedure for open-source macOS apps without notarization.

## Risks / Trade-offs

- **Gatekeeper friction**: Users who are not comfortable with Terminal commands may be unable to run the app. → Mitigation: Provide clear, copy-paste instructions in README with exact commands.
- **Runner Xcode version drift**: `macos-latest` image changes over time and may break builds if the project requires a specific Xcode version. → Mitigation: Pin to a specific runner image (e.g., `macos-15`) once stable; add a note to the workflow.
- **No automated tests**: The workflow builds and ships without running tests, so regressions could be released. → Accepted trade-off for now; out of scope for this change.
- **Ad-hoc signing on Apple Silicon**: Ad-hoc signing is sufficient for the user's own machine or users who follow the `xattr` instructions. It is not a substitute for proper distribution signing. → Accepted given the project's personal/open-source nature.
