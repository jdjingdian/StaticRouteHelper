## MODIFIED Requirements

### Requirement: Ad-hoc code sign the app bundle
The workflow SHALL sign the built `.app` bundle using ad-hoc signing so that the binary satisfies macOS execution requirements without a paid certificate. The signing SHALL be performed in two explicit steps: first signing the privileged helper binary directly, then signing the app bundle itself (without `--deep`). This ensures the helper receives a proper ad-hoc signature with a bound Info.plist rather than the `linker-signed` stub left by the Xcode linker.

#### Scenario: Helper is signed before app bundle
- **WHEN** the `.app` bundle is built successfully
- **THEN** `codesign --force --sign -` SHALL be run on the helper binary at `Contents/Library/LaunchServices/cn.magicdian.staticrouter.helper` first
- **THEN** `codesign --force --sign -` SHALL be run on the `.app` bundle (without `--deep`)
- **THEN** `codesign --verify --deep` SHALL succeed on the signed bundle

#### Scenario: Helper signature is valid for SMJobBless
- **WHEN** signing completes
- **THEN** `codesign -dvvv` on the helper SHALL NOT show `linker-signed` in its flags
- **THEN** `codesign -dvvv` on the helper SHALL show `Info.plist entries=N` (Info.plist is bound)
- **THEN** SMJobBless SHALL be able to install the helper without `errSecInvalidSignature` (-67062)
