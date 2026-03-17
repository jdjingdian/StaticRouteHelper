### Requirement: Workflow triggers on release publication
The system SHALL include a GitHub Actions workflow file at `.github/workflows/release.yml` that triggers automatically when a GitHub Release is published (event type: `release`, activity type: `published`).

#### Scenario: Workflow triggers on published release
- **WHEN** a GitHub Release is published in the repository
- **THEN** the GitHub Actions workflow SHALL start running automatically

#### Scenario: Workflow does not trigger on draft
- **WHEN** a GitHub Release is saved as a draft (not published)
- **THEN** the GitHub Actions workflow SHALL NOT run

### Requirement: Build macOS app using xcodebuild
The workflow SHALL build the macOS application using `xcodebuild` on a GitHub-hosted macOS runner, producing a valid `.app` bundle in a known output directory.

#### Scenario: Successful build
- **WHEN** the workflow runs on a macOS runner with `xcodebuild` available
- **THEN** `xcodebuild` SHALL compile the project and produce a `.app` bundle
- **THEN** the build SHALL use the `Release` configuration

#### Scenario: Build failure stops workflow
- **WHEN** `xcodebuild` exits with a non-zero code
- **THEN** the workflow SHALL fail and SHALL NOT proceed to signing or packaging

### Requirement: Ad-hoc code sign the app bundle
The workflow SHALL sign the built `.app` bundle using ad-hoc signing (`codesign --force --deep --sign -`) so that the binary satisfies macOS execution requirements without a paid certificate.

#### Scenario: Ad-hoc signing applied
- **WHEN** the `.app` bundle is built successfully
- **THEN** `codesign --force --deep --sign -` SHALL be run on the `.app` bundle
- **THEN** `codesign --verify` SHALL succeed on the signed bundle

### Requirement: Package app as zip archive using ditto
The workflow SHALL package the ad-hoc signed `.app` bundle into a `.zip` archive using `ditto -c -k --keepParent` to preserve macOS metadata.

#### Scenario: Zip created successfully
- **WHEN** ad-hoc signing succeeds
- **THEN** `ditto` SHALL produce a `.zip` file containing the `.app` bundle
- **THEN** the `.zip` file name SHALL include the app name and the release tag (e.g., `StaticRouteHelper-v1.0.0.zip`)

### Requirement: Upload zip to GitHub Release
The workflow SHALL upload the packaged `.zip` archive as an asset attached to the triggering GitHub Release using the GitHub Actions release asset upload mechanism.

#### Scenario: Asset attached to release
- **WHEN** the `.zip` is created successfully
- **THEN** the workflow SHALL upload the `.zip` to the GitHub Release that triggered the workflow
- **THEN** the asset SHALL be visible and downloadable on the GitHub Release page

### Requirement: Workflow uses GitHub-hosted macOS runner
The workflow SHALL run on a GitHub-hosted macOS runner (e.g., `macos-latest`) that has `xcodebuild` pre-installed, requiring no self-hosted infrastructure.

#### Scenario: Runner is available
- **WHEN** the workflow is triggered
- **THEN** it SHALL be assigned a GitHub-hosted macOS runner automatically
