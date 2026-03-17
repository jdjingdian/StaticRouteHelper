## Context

项目使用单一 `project.pbxproj` 文件作为版本号的唯一来源（在上一个 change `unify-version-source-of-truth` 中完成了整合）。当前版本更新需要手动编辑 pbxproj 中 4 处：两个 target（`RouteHelper`、`Static Router`）× 两个 configuration（Debug、Release）。

pbxproj 中的版本相关行：

| 行号 | 内容 |
|------|------|
| 539 | `CURRENT_PROJECT_VERSION = 14;` (RouteHelper Debug) |
| 569 | `CURRENT_PROJECT_VERSION = 14;` (RouteHelper Release) |
| 731 | `CURRENT_PROJECT_VERSION = 14;` (Static Router Debug) |
| 733 | `MARKETING_VERSION = 1.4.0;` (Static Router Debug) |
| 761 | `CURRENT_PROJECT_VERSION = 14;` (Static Router Release) |
| 763 | `MARKETING_VERSION = 1.4.0;` (Static Router Release) |

系统工具约束：macOS 内置的是 BSD `sed`，行为与 GNU sed 不同（`-i` 需要跟扩展名参数）。

## Goals / Non-Goals

**Goals:**
- 提供 `scripts/bump-version.sh`，接受单个参数 `MARKETING_VERSION`（如 `1.5.0`）
- `CURRENT_PROJECT_VERSION` 由脚本自动通过 `git rev-list --count HEAD` 计算
- 一次性更新 pbxproj 中所有 4 处 `CURRENT_PROJECT_VERSION` 和 2 处 `MARKETING_VERSION`
- 包含参数格式校验（semver 格式 `X.Y.Z`）
- 完成后打印变更摘要，让开发者确认结果

**Non-Goals:**
- 不自动执行 git commit 或 tag
- 不集成到 CI/GitHub Actions（该脚本为本地工具）
- 不支持 pre-release 标识符（如 `1.5.0-beta`）
- 不修改 `RouteHelper/Info.plist` 或 `StaticRouter/Info.plist`（它们已使用变量引用）

## Decisions

### 1. 使用 `sed` 直接修改 pbxproj，而非 `agvtool`

**选择：** BSD `sed` 全局替换。

**理由：** `agvtool` 需要在 pbxproj 中设置 `VERSIONING_SYSTEM = apple-generic`，会引入额外的 build setting 变更。直接用 `sed` 无需任何前置配置，且 pbxproj 是纯文本文件，模式稳定可预测。调研显示主流开源 macOS 项目（Rectangle、Stats、Maccy）均采用直接文件修改方式，无人使用 agvtool。

**替代方案：** PlistBuddy — 仅适用于 plist，无法操作 pbxproj 格式。

### 2. Build number 使用 `git rev-list --count HEAD`

**选择：** 从 git commit 总数自动派生。

**理由：** 单调递增，无需手动维护，每次提交后自动增大，与 marketing version 解耦。当前项目有 45 次提交，build 14，说明历史上 build 号并非严格等于 commit 数——这是预期的，脚本运行后两者将重新对齐，后续保持同步。

**替代方案：** 手动传入第二个参数 — 增加使用复杂度，违背"一个参数"的设计目标。

### 3. macOS BSD sed 的 `-i` 用法

**选择：** 使用 `sed -i '' 's/pattern/replacement/g'`（BSD sed 语法）。

**理由：** 脚本目标运行环境是 macOS 开发机，macOS 内置 BSD sed，`-i` 必须跟一个扩展名参数（空字符串 `''` 表示原地修改不备份）。若使用 GNU sed 语法（`-i` 不跟参数）会报错。脚本顶部添加注释说明此限制。

## Risks / Trade-offs

- **pbxproj 格式依赖**：`sed` 基于文本模式匹配，若 Xcode 重新格式化 pbxproj（如重排 build settings 顺序），脚本无需修改，因为替换的是值本身（`= X;` → `= Y;`）而非行位置。风险极低。

- **Build number 与历史不连续**：首次运行后 build number 将从 14 跳到当前 commit 数（45）。这是一次性跳跃，对 App 功能无影响，但 build 历史记录中会有跨越。→ 可接受，在脚本输出中提示开发者。

- **并发修改**：若多人同时在不同分支运行脚本，merge 时 pbxproj 会有冲突。→ 本工具定位为发布前的本地操作，冲突概率低，且 pbxproj 冲突本就是常见情况，已有处理经验。
