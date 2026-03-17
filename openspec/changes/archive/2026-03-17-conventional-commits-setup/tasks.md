## 1. Create Git Commit Template

- [x] 1.1 Create `.gitmessage` file at repo root with Conventional Commits format and inline type/scope/body/footer guidance comments
- [x] 1.2 Configure local git to use the template: `git config --local commit.template .gitmessage`
- [x] 1.3 Verify `git config --local commit.template` returns `.gitmessage`

## 2. Update OpenSpec Propose Skill

- [x] 2.1 Open `.opencode/skills/openspec-propose/SKILL.md`
- [x] 2.2 Add a final step (Step 6) to the **Steps** section that instructs the skill to output a Conventional Commits-compliant commit message suggestion after all artifacts are created (format: `docs(openspec): propose <change-name>`)
- [x] 2.3 Verify the SKILL.md change is saved and the new step is visible in the file

## 3. Verify

- [x] 3.1 Run `git commit` (without `-m`) in a test scenario and confirm the template is pre-loaded in the editor
- [x] 3.2 Confirm `.gitmessage` is tracked by git (`git status` shows it as a new file)
