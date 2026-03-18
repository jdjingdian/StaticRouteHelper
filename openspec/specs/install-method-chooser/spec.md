## ADDED Requirements

### Requirement: 安装方式选择对话框
在 macOS 14+ 上，当用户点击"安装"按钮时，系统 SHALL 弹出一个 Sheet 对话框，展示两种安装方式供用户选择：SMAppService（标记为推荐）和 SMJobBless。对话框 SHALL 包含每种方式的简要描述，以及"取消"和"安装"按钮。用户选择后点击"安装"，系统执行对应的安装流程。

#### Scenario: macOS 14+ 用户首次安装
- **WHEN** 用户在 macOS 14+ 上点击"安装"按钮
- **THEN** 弹出 Sheet 对话框，默认选中 SMAppService（推荐），同时显示 SMJobBless 选项

#### Scenario: 用户选择 SMAppService 安装
- **WHEN** 用户在对话框中选择 SMAppService 并点击"安装"
- **THEN** 系统调用 `SMAppService.daemon(...).register()` 执行安装，成功后 `activeMethod` 更新为 `.smAppService`

#### Scenario: 用户选择 SMJobBless 安装
- **WHEN** 用户在对话框中选择 SMJobBless 并点击"安装"
- **THEN** 系统调用 `authorizeAndBless()` 执行安装（弹出系统授权对话框），成功后 `activeMethod` 更新为 `.smJobBless`

#### Scenario: 用户取消安装
- **WHEN** 用户在对话框中点击"取消"
- **THEN** 对话框关闭，不执行任何安装操作，`activeMethod` 保持不变

### Requirement: macOS 12–13 保持直接安装
在 macOS 12–13 上，点击"安装"按钮 SHALL 直接执行 SMJobBless 安装（与当前行为一致），不弹出选择对话框。

#### Scenario: macOS 13 用户安装
- **WHEN** 用户在 macOS 13 上点击"安装"按钮
- **THEN** 系统直接调用 `authorizeAndBless()` 弹出授权对话框，无方式选择步骤

### Requirement: 用户偏好持久化
系统 SHALL 通过 `@AppStorage` (UserDefaults) 持久化用户在 macOS 14+ 上选择的安装方式偏好（key: `preferredInstallMethod`）。卸载后重新安装时，选择器 SHALL 默认选中用户上次的偏好。

#### Scenario: 记住用户偏好
- **WHEN** 用户选择 SMJobBless 安装成功，之后卸载 Helper，再次点击"安装"
- **THEN** 选择对话框中 SMJobBless 为默认选中项（而非 SMAppService）

#### Scenario: 首次安装无偏好记录
- **WHEN** 用户从未安装过 Helper（无偏好记录），点击"安装"
- **THEN** 选择对话框默认选中 SMAppService（推荐）

### Requirement: 切换安装方式必须先卸载
在 macOS 14+ 上，如果 Helper 已安装（任一方式），用户 SHALL 不能直接切换到另一种方式。切换路径为：卸载当前 Helper → 重新安装时选择新方式。

#### Scenario: 已安装 SMJobBless 想切换到 SMAppService
- **WHEN** Helper 通过 SMJobBless 安装且处于已安装状态，用户想使用 SMAppService
- **THEN** 用户必须先在设置页点击"卸载"，卸载完成后再点击"安装"并在对话框中选择 SMAppService
