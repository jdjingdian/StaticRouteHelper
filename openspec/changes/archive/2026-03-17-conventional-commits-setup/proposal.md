## Why

The project currently lacks a standardized git commit message format, making it difficult to understand the history and intent of changes at a glance. Adopting the Conventional Commits specification enforces a consistent, machine-readable commit format that improves changelog generation, semantic versioning, and team collaboration. Additionally, the OpenSpec propose workflow should automatically suggest compliant commit messages after proposals are created, reinforcing the practice.

## What Changes

- Add a git commit message template (`~/.gitmessage` or `.gitmessage` at repo root) that follows Conventional Commits format
- Configure git to use the template via `commit.template` setting
- Update the OpenSpec propose workflow (skill instructions) so that after all artifacts are created, it outputs a suggested Conventional Commits-compliant commit message for the change

## Capabilities

### New Capabilities

- `git-commit-template`: A git commit message template file and git configuration that enforces Conventional Commits format (`<type>(<scope>): <subject>`) with inline guidance comments

### Modified Capabilities

- (none)

## Impact

- Affects the local git configuration for this repository
- Affects the `.opencode/skills/openspec-propose/SKILL.md` skill instructions (adds a final step to output a commit log suggestion)
- No code changes to the application itself; purely developer tooling and workflow
