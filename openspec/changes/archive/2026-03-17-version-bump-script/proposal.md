## Why

手动修改 `project.pbxproj` 来更新版本号需要在 4 个位置（两个 target × 两个 build configuration）重复操作，容易遗漏或写错。引入一个自动化脚本，只需传入 marketing version，即可一次性完成所有更新，同时从 git 提交次数自动派生 build number。

## What Changes

- 新增 `scripts/bump-version.sh` 脚本，接受一个参数（`MARKETING_VERSION`，如 `1.5.0`），自动计算 `CURRENT_PROJECT_VERSION`（git commit 总数），并将两个值写入 `project.pbxproj` 中所有相关位置
- 脚本包含参数校验、版本号格式验证和操作结果确认输出
- 在 `README` 中补充版本发布流程说明（可选）

## Capabilities

### New Capabilities

- `version-bump`: 通过单条脚本命令更新 pbxproj 中所有版本相关 build settings，build number 从 git commit 数自动派生

### Modified Capabilities

（无）

## Impact

- 影响文件：`StaticRouteHelper.xcodeproj/project.pbxproj`（脚本的写入目标）
- 新增文件：`scripts/bump-version.sh`
- 无 API 变更，无依赖引入，不影响构建系统本身
- 脚本在 macOS 本地环境运行，依赖 `git`、`sed`（macOS BSD sed）、`grep`，均为系统内置工具
