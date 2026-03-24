## ADDED Requirements

### Requirement: UI 设计规范文档必须作为后续 UI 开发基线
The project MUST treat `design/STYLE_GUIDE.md` as the baseline for UI-related implementation decisions, including visual tokens, component patterns, hierarchy, and interaction behavior.

#### Scenario: 新增 UI 变更提案时引用设计基线
- **WHEN** a new change proposes UI modifications
- **THEN** the proposal/design artifacts MUST reference `design/STYLE_GUIDE.md` as the style baseline
- **AND** the change description MUST explain alignment with existing style rules or explicitly list justified deviations

### Requirement: design 目录必须作为 UI 规范统一入口
The project MUST keep `design/README.md` and `design/STYLE_GUIDE.md` as the canonical documentation entry for UI style governance.

#### Scenario: 团队成员查阅 UI 规范
- **WHEN** contributors need UI guidance for implementation or review
- **THEN** they MUST use the `design/` documents as the primary reference instead of ad-hoc style choices

### Requirement: 设计基线变更必须先文档化后实现
Any change to core UI style rules (color tokens, control sizing patterns, interaction conventions, layout hierarchy) MUST update style documentation before or together with implementation changes.

#### Scenario: 调整核心视觉 token
- **WHEN** a change updates core design tokens or component rules
- **THEN** `design/STYLE_GUIDE.md` MUST be updated in the same change
- **AND** the change MUST include a brief rationale for the update
