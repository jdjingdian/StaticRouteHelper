## 上下文

本次 UI 重构已经通过 `ui-ux-pro-max` 技能完成，且项目内已有正式设计文档：

- `design/STYLE_GUIDE.md`
- `design/README.md`

当前问题不是“如何再做一版 UI”，而是“如何把已确认的风格长期固化到后续开发流程中”。如果没有在 OpenSpec 中定义规范能力，后续功能迭代可能在控件尺寸、层级、交互反馈和视觉 token 上出现漂移。

## 目标 / 非目标

**目标：**

- 在 OpenSpec 中建立 `ui-style-governance` 能力，明确 UI 变更必须遵循设计文档。
- 规定 `design/` 目录是 UI 规范的统一来源，并作为后续提案/设计阶段的引用依据。
- 为后续 UI 开发提供一致的评审与验收标准（而不是仅凭主观审美）。

**非目标：**

- 不新增业务功能。
- 不引入额外代码重构或视觉改版。
- 不改变现有运行时行为、接口或数据模型。

## 决策

### 决策 1：以现有设计文档作为唯一基线（Single Source of Truth）

- 采用 `design/STYLE_GUIDE.md` 作为风格规则主文档，`design/README.md` 作为入口。
- 原因：文档已落地并且对应当前代码实现，迁移成本最低。
- 备选方案：在 OpenSpec 内重复维护一份完整视觉规则。未采用，避免双份文档长期分叉。

### 决策 2：通过新 capability 管理“流程约束”而非“功能逻辑”

- 新增 `ui-style-governance` 规范能力，约束未来 UI 相关提案必须声明与 style guide 的一致性。
- 原因：本次需求本质是治理与规范沉淀，不是新功能开发。
- 备选方案：仅在 README 写约定。未采用，因无法进入 OpenSpec 变更审查与可追踪链路。

### 决策 3：本次变更仅文档化，不触发额外实现任务

- 任务聚焦在产出 proposal/design/spec/tasks 文档，标注无需新增代码。
- 原因：用户明确要求“本次提案不需要额外代码变更”。

## 风险 / 权衡

- [风险] 文档规范存在但执行不到位，后续提交仍可能偏离。  
  → 缓解：在规范中增加“UI 变更需说明与 `design/STYLE_GUIDE.md` 对齐”的要求，并在任务中要求评审对照。

- [风险] 后续样式演进时未及时更新文档。  
  → 缓解：要求涉及视觉 token、组件交互策略变更时先更新 `design/STYLE_GUIDE.md` 再改代码。

- [权衡] 增加了一层流程约束，短期会提高提案书写成本。  
  → 收益是长期一致性提升，减少返工和样式回退。

## Migration Plan

1. 合入本次变更文档（proposal/design/spec/tasks）。
2. 后续 UI 类变更在 proposal/design 中引用 `design/STYLE_GUIDE.md`。
3. 评审阶段按 `ui-style-governance` 规范检查是否满足设计基线。
4. 如需变更设计基线，先更新 `design/` 文档，再提交对应 OpenSpec 变更。

## Open Questions

- 当前无阻塞性开放问题。
- 后续如需引入主题变体（例如高对比度模式），可作为 `ui-style-governance` 的后续增量变更处理。
