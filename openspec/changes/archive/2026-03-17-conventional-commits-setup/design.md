## Context

The project has no standardized git commit message format. Commits vary in style and clarity, making it harder to review history and understand intent. The project uses a local git repository and the OpenCode/OpenSpec workflow for managing changes.

Two surfaces need updating:
1. **Git tooling**: A `.gitmessage` template file at repo root + `git config commit.template` pointing to it
2. **OpenSpec propose skill**: `SKILL.md` needs a final step that outputs a Conventional Commits-compliant commit suggestion after all artifacts are created

## Goals / Non-Goals

**Goals:**
- Create a `.gitmessage` commit template with Conventional Commits format and inline guidance comments
- Configure the local repo to use the template automatically (`git config --local commit.template`)
- Extend `openspec-propose` skill to output a suggested commit message (e.g., `docs(openspec): propose <change-name>`) after proposal is complete

**Non-Goals:**
- Installing any commit linting tools (commitlint, husky, etc.)
- Enforcing the format via git hooks
- Modifying global git config (scope is repo-local only)
- Retroactively reformatting existing commits

## Decisions

### D1: Template location — repo root `.gitmessage` vs `~/.gitmessage`

**Decision**: Repo root (`.gitmessage`), committed to version control.

**Rationale**: Keeps the template discoverable and version-controlled with the project. All contributors get the same template when they run `git config --local commit.template .gitmessage`. A global `~/.gitmessage` would only affect the current user's machine and not be shared.

### D2: Template content structure

**Decision**: Include type list as comments inside the template, not as a separate README.

**Rationale**: Inline comments appear directly in the editor when committing, providing just-in-time guidance without requiring the developer to look elsewhere.

Format:
```
<type>(<scope>): <subject>

# Body (optional): explain what and why, not how
# Max 72 chars per line

# Footer (optional): BREAKING CHANGE, closes #<issue>

# --- Types ---
# feat:     A new feature
# fix:      A bug fix
# docs:     Documentation only changes
# style:    Formatting, whitespace (no logic change)
# refactor: Code change that is neither fix nor feature
# test:     Adding or updating tests
# chore:    Build process, tooling, dependencies
# ci:       CI/CD configuration changes
# perf:     Performance improvements
```

### D3: Scope definition for this project

**Decision**: Use directory/module names as scope (e.g., `openspec`, `routes`, `ui`, `pf`).

**Rationale**: Matches the project's domain areas visible in the codebase structure.

### D4: Skill modification approach for propose

**Decision**: Add a "Step 6: Output commit message suggestion" to `openspec-propose` SKILL.md.

**Rationale**: Non-invasive — appends to the existing workflow without restructuring it. The commit suggestion is formatted as:
```
docs(openspec): propose <change-name>
```
This tells the developer what commit to make after running the propose command.

## Risks / Trade-offs

- **Risk**: Developer ignores the template → **Mitigation**: Template appears automatically in editor on `git commit`; no hard enforcement needed for now
- **Risk**: SKILL.md modification diverges from upstream openspec updates → **Mitigation**: The addition is isolated to a clearly-marked final step; easy to diff and re-apply
- **Trade-off**: Repo-local config means each contributor must run `git config --local commit.template .gitmessage` once after cloning → acceptable given small team size; can document in README if needed
