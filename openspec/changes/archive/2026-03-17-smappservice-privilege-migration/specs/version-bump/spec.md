## MODIFIED Requirements

### Requirement: Script accepts a single MARKETING_VERSION argument
脚本 `scripts/bump-version.sh` SHALL 接受且仅接受一个位置参数，即新的 `MARKETING_VERSION`，格式为 `X.Y.Z`（三段纯数字，点分隔）。

#### Scenario: 提供合法的 semver 参数
- **WHEN** 用户执行 `./scripts/bump-version.sh 2.0.0`
- **THEN** 脚本继续执行版本更新流程

#### Scenario: 未提供参数
- **WHEN** 用户执行 `./scripts/bump-version.sh`（无参数）
- **THEN** 脚本打印用法说明并以非零退出码退出，不修改任何文件

#### Scenario: 参数格式不合法
- **WHEN** 用户执行 `./scripts/bump-version.sh 2.0`（格式不符合 X.Y.Z）
- **THEN** 脚本打印格式错误提示并以非零退出码退出，不修改任何文件

### Requirement: Build number 从 git commit 数自动派生
脚本 SHALL 通过 `git rev-list --count HEAD` 获取当前仓库的 git commit 总数，并将其用作 `CURRENT_PROJECT_VERSION`，无需用户手动传入。

#### Scenario: 在 git 仓库中执行
- **WHEN** 脚本在有效的 git 仓库根目录执行
- **THEN** `CURRENT_PROJECT_VERSION` 自动设置为当前 commit 总数

#### Scenario: 不在 git 仓库中执行
- **WHEN** 脚本在非 git 仓库目录执行
- **THEN** 脚本打印错误提示并以非零退出码退出，不修改任何文件

### Requirement: 更新 pbxproj 中所有版本 build settings
脚本 SHALL 使用 BSD `sed` 原地修改 `StaticRouteHelper.xcodeproj/project.pbxproj`，将文件中全部的 `CURRENT_PROJECT_VERSION = <旧值>;` 替换为新值，以及全部的 `MARKETING_VERSION = <旧值>;` 替换为新值。

#### Scenario: 成功替换所有版本值
- **WHEN** 脚本以 `2.0.0` 为参数执行
- **THEN** pbxproj 中 4 处 `CURRENT_PROJECT_VERSION` 和 2 处 `MARKETING_VERSION` 均被更新为新值

#### Scenario: 替换后值可验证
- **WHEN** 脚本执行完毕
- **THEN** `grep MARKETING_VERSION project.pbxproj` 仅返回 `2.0.0`，无旧值残留

### Requirement: 打印操作摘要
脚本 SHALL 在执行完毕后向标准输出打印本次操作的摘要，包含：旧版本号、新版本号、旧 build number、新 build number。

#### Scenario: 正常执行后的输出
- **WHEN** 脚本成功将版本更新至 `2.0.0`
- **THEN** 标准输出包含形如 `Version: 1.4.0 -> 2.0.0` 和对应 build number 摘要行
