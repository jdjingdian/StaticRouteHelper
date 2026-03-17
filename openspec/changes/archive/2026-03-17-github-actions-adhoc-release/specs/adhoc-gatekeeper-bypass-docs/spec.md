## ADDED Requirements

### Requirement: English README documents download and Gatekeeper bypass
The `README.md` file SHALL include a "Download & Installation" (or equivalent) section that explains how to download the pre-built release binary and remove the Gatekeeper quarantine attribute using `xattr -cr`.

#### Scenario: User reads English README
- **WHEN** a user visits the GitHub repository and reads `README.md`
- **THEN** they SHALL find clear instructions for downloading the `.zip` from the Releases page
- **THEN** they SHALL find an exact, copy-paste `xattr -cr` command to remove the quarantine flag
- **THEN** the instructions SHALL explain why the step is necessary (no notarization / no paid certificate)

### Requirement: Chinese README documents download and Gatekeeper bypass
The `README_CN.md` file SHALL include a Chinese-language section equivalent to the English one, explaining how to download the release binary and bypass Gatekeeper using `xattr -cr`.

#### Scenario: User reads Chinese README
- **WHEN** a user visits the GitHub repository and reads `README_CN.md`
- **THEN** they SHALL find Chinese-language instructions for downloading the `.zip` from the Releases page
- **THEN** they SHALL find an exact, copy-paste `xattr -cr` command
- **THEN** the instructions SHALL explain the reason in Chinese (未签名 / 无付费开发者证书)

### Requirement: Gatekeeper bypass command is accurate and copy-pasteable
The `xattr` command provided in both README files SHALL be syntactically correct and directly runnable in macOS Terminal without modification (aside from substituting the actual path to the app if needed).

#### Scenario: Command removes quarantine attribute
- **WHEN** a user runs `xattr -cr /path/to/StaticRouteHelper.app`
- **THEN** the `com.apple.quarantine` extended attribute SHALL be removed
- **THEN** macOS SHALL allow the app to launch without a Gatekeeper warning
