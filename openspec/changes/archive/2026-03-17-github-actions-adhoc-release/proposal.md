## Why

The project currently has no automated build or release process. Publishing a new release requires manual compilation, signing, and packaging on a developer's local machine. Without an Apple paid developer certificate, distributing a properly notarized binary is not possible, so we adopt an ad-hoc signing approach combined with clear user instructions for bypassing Gatekeeper — enabling automated, reproducible releases triggered directly from GitHub.

## What Changes

- Add a GitHub Actions workflow that triggers on GitHub Release publication
- Build the macOS app using `xcodebuild` in the CI environment
- Sign the app binary with ad-hoc signing (`codesign --force --deep --sign -`)
- Package the signed app into a `.zip` archive
- Upload the archive as a release asset automatically
- Update README.md (English) with download and Gatekeeper bypass instructions
- Update README_CN.md (Chinese) with the same instructions in Chinese

## Capabilities

### New Capabilities

- `github-actions-release`: Automated CI/CD workflow that builds, ad-hoc signs, packages, and publishes the macOS app as a GitHub Release asset on every release event
- `adhoc-gatekeeper-bypass-docs`: User-facing documentation (in both English and Chinese README files) explaining how to download the release and remove Gatekeeper restrictions using `xattr`

### Modified Capabilities

<!-- None — no existing spec-level behavior changes -->

## Impact

- **New files**: `.github/workflows/release.yml`
- **Modified files**: `README.md`, `README_CN.md`
- **Build system**: Requires `xcodebuild` available on the GitHub-hosted macOS runner
- **Distribution**: App binary will not be notarized; users must run `xattr -cr` to bypass Gatekeeper
- **No source code changes** to the Swift/SwiftUI application itself
