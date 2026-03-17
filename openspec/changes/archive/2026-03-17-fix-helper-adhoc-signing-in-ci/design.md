## Context

The project uses SMJobBless to install a privileged helper tool (`cn.magicdian.staticrouter.helper`). Because the project targets ad-hoc signing only (no Apple Developer certificate), the GitHub Actions CI workflow must produce a properly ad-hoc signed app bundle.

Prior to this fix, the CI build was run with code signing completely disabled (`CODE_SIGNING_ALLOWED=NO`). A subsequent step applied `codesign --force --deep --sign -` to the `.app` bundle. However, Xcode's linker had already embedded a minimal `linker-signed` ad-hoc signature into the helper binary at build time. The `--deep` flag used by `codesign` skips re-signing any binary that is already signed — so the helper was left with a `linker-signed` signature that did not have a bound Info.plist.

SMJobBless validates the embedded helper against the requirement string listed in the main app's `SMPrivilegedExecutables` Info.plist key. Even with an identifier-only requirement (`identifier "cn.magicdian.staticrouter.helper"`), the system must be able to evaluate a complete code signature. A `linker-signed` binary without a bound Info.plist fails this check with `errSecInvalidSignature` (-67062).

## Goals / Non-Goals

**Goals:**
- Ensure the helper binary has a proper ad-hoc signature (not `linker-signed`) with its Info.plist bound after the CI build.
- Fix SMJobBless `-67062` for users running the GitHub Actions release build.
- Keep the approach simple — no changes to source code, plists, or Xcode project settings.

**Non-Goals:**
- Notarization (requires Apple Developer account; out of scope for ad-hoc builds).
- Changing the Xcode build settings to re-enable signing during the build step.
- Signing any other nested binaries (frameworks, plugins) beyond the helper.

## Decisions

### Decision: Sign helper explicitly before signing the app bundle

**Chosen approach**: Add a dedicated `codesign --force --sign - <helper-path>` step before the app-level signing step. Remove `--deep` from the app signing step.

**Rationale**: 
- `--deep` is documented by Apple as unreliable for production use and specifically skips already-signed content. By signing the helper first with `--force`, we override the `linker-signed` stub and produce a proper ad-hoc signature with a bound Info.plist.
- Signing the app bundle last (without `--deep`) seals the bundle's resource envelope, which must happen after nested binaries are finalized.
- The verify step retains `--deep` (`codesign --verify --deep`) to confirm the entire hierarchy is clean.

**Alternative considered**: Re-enable Xcode code signing during the build step (`CODE_SIGN_IDENTITY="-"`). Rejected because it would require the CI runner to satisfy Xcode's keychain/provisioning checks, adding complexity and fragility for a no-certificate setup.

## Risks / Trade-offs

- **Risk**: If additional nested binaries acquire `linker-signed` stubs in the future (e.g., frameworks), they would also need explicit signing steps.  
  → **Mitigation**: The verify step (`codesign --verify --deep`) will catch unsigned or improperly signed nested content and fail the CI job.

- **Trade-off**: Removing `--deep` from the signing step means any future nested binary that is not explicitly pre-signed will not be signed at all (rather than receiving a shallow `linker-signed` pass). This is actually safer — it makes missing signatures visible as CI failures rather than silent linker-signed stubs.
