### Requirement: Helper binary is explicitly ad-hoc signed before app bundle signing
The CI workflow SHALL explicitly sign the privileged helper binary (`cn.magicdian.staticrouter.helper`) with `codesign --force --sign -` as a dedicated step before signing the app bundle. This ensures the helper receives a proper ad-hoc signature with its embedded Info.plist bound, overriding any `linker-signed` stub left by the Xcode linker.

#### Scenario: Helper has proper ad-hoc signature after CI build
- **WHEN** the CI workflow completes the signing steps
- **THEN** `codesign -dvvv` on the helper SHALL show `flags=0x2(adhoc)` (NOT `adhoc,linker-signed`)
- **THEN** `codesign -dvvv` on the helper SHALL show `Info.plist entries=N` where N > 0 (Info.plist is bound)

#### Scenario: Helper signing precedes app bundle signing
- **WHEN** the CI signing step runs
- **THEN** the helper binary SHALL be signed before the app bundle is signed
- **THEN** the app bundle signing step SHALL NOT use `--deep` (to avoid skipping the already-signed helper)

#### Scenario: Full bundle verification passes
- **WHEN** signing is complete
- **THEN** `codesign --verify --deep` on the `.app` bundle SHALL exit with code 0
