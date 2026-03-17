### Requirement: Git commit template file exists
The repository SHALL include a `.gitmessage` file at the root that contains a Conventional Commits-formatted template with inline comment guidance.

#### Scenario: Template file is present
- **WHEN** a developer clones the repository and lists the root directory
- **THEN** a `.gitmessage` file SHALL be present

#### Scenario: Template contains type-scope-subject header
- **WHEN** the developer opens `.gitmessage`
- **THEN** the first non-comment line SHALL follow the format `<type>(<scope>): <subject>`

#### Scenario: Template includes type reference comments
- **WHEN** the developer opens `.gitmessage`
- **THEN** comments SHALL list all Conventional Commits types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `perf`

#### Scenario: Template includes body and footer guidance
- **WHEN** the developer opens `.gitmessage`
- **THEN** comments SHALL guide on optional body (what/why, 72-char line limit) and footer (BREAKING CHANGE, issue references)

### Requirement: Git local config uses commit template
The local git configuration SHALL set `commit.template` to point to `.gitmessage` so that `git commit` automatically loads the template.

#### Scenario: Template is loaded on commit
- **WHEN** the developer runs `git commit` without `-m`
- **THEN** the editor SHALL open with the `.gitmessage` template pre-populated

#### Scenario: Config is repo-local
- **WHEN** the developer inspects `git config --local commit.template`
- **THEN** the value SHALL be `.gitmessage`

### Requirement: OpenSpec propose outputs commit suggestion
After the openspec-propose workflow completes all artifacts, the skill SHALL output a suggested Conventional Commits-compliant commit message for the change.

#### Scenario: Commit suggestion is output after propose
- **WHEN** all artifacts for a change are created via the propose workflow
- **THEN** the output SHALL include a suggested commit message in the form `docs(openspec): propose <change-name>`

#### Scenario: Commit suggestion follows Conventional Commits format
- **WHEN** the commit suggestion is output
- **THEN** it SHALL conform to `<type>(<scope>): <subject>` format with type `docs` and scope `openspec`
