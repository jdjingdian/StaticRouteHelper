## Why

The GitHub Actions CI build was producing a helper binary with a `linker-signed` ad-hoc signature, which left the Info.plist unbound. SMJobBless validates the helper's signature against the `SMPrivilegedExecutables` requirement at install time, and a `linker-signed` binary without a bound Info.plist fails that check with `errSecInvalidSignature` (-67062), making it impossible for users to install the privileged helper.

## What Changes

- The CI signing step is updated to explicitly sign the helper binary **before** signing the app bundle, ensuring the helper receives a proper ad-hoc signature with its Info.plist bound.
- The `--deep` flag is removed from the app bundle signing step, since nested binaries are now signed individually first. The verify step retains `--deep` to confirm the full bundle hierarchy.

## Capabilities

### New Capabilities
- `ci-helper-explicit-signing`: The CI workflow explicitly signs the privileged helper binary as a separate codesign step before signing the app bundle, guaranteeing a proper ad-hoc signature with a bound Info.plist.

### Modified Capabilities
- `github-actions-release`: The ad-hoc signing step within the release workflow changes to sign the helper individually before signing the app, rather than relying on `--deep` to propagate the signature.

## Impact

- `.github/workflows/release.yml`: The "Ad-hoc sign the app bundle" step is modified.
- No changes to source code, plists, or Xcode project settings.
- Users downloading the GitHub Actions release will no longer encounter `-67062` when installing the privileged helper.
