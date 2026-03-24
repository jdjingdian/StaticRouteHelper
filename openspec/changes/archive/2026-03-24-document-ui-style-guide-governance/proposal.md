## 为什么

本次通过 UI UX Pro MAX 已经完成了界面重构，并落盘了 `design/STYLE_GUIDE.md` 与 `design/README.md`。但当前项目在 OpenSpec 体系内尚未把这套设计规范作为“后续 UI 迭代必须遵循的能力”进行正式记录，后续开发存在风格回退和实现不一致风险。

## 变更内容

- 将本次 UI 重构沉淀出的视觉与交互规范，登记为 OpenSpec 的长期治理能力。
- 明确后续 UI 相关改动在提案与实现阶段应引用 `design/STYLE_GUIDE.md` 作为设计基线。
- 明确设计文档目录（`design/`）作为项目 UI 规范的统一入口与维护位置。
- 本次提案不引入新增功能代码，不要求额外 UI 实现改动。

## 功能 (Capabilities)

### 新增功能
- `ui-style-governance`: 将 UI 风格规范文档纳入项目治理，要求后续 UI 改动遵循既定设计语言与组件规则。

### 修改功能
- （无）

## 影响

- 文档与规范：`design/STYLE_GUIDE.md`、`design/README.md` 将被定义为后续 UI 开发的规范依据。
- OpenSpec 资产：新增 `openspec/changes/document-ui-style-guide-governance/` 下提案、设计、任务和规格文档。
- 代码与运行时行为：无直接影响。
