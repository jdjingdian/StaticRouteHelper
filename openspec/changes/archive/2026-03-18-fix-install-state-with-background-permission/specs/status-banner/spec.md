## MODIFIED Requirements

### Requirement: 主窗口横幅显示逻辑
主窗口详情区域顶部 SHALL 根据以下条件按优先级显示一个横幅（互斥，只显示最高优先级）：

1. **优先级 1** — `helperStatus == .pendingActivation`：显示 `.warning` 横幅，消息提示 Helper 已安装但待生效（需开启后台运行开关），按钮引导到设置页
2. **优先级 2** — `helperStatus != .installed` 且 `helperStatus != .pendingActivation`：显示 `.warning` 横幅，消息提示 Helper 未安装，按钮引导到设置页
3. **优先级 3** — macOS 14+ 且 `activeMethod == .smJobBless` 且 `helperStatus == .installed`：显示 `.info` 横幅，消息提示有更现代的部署方式可用，按钮引导到设置页（卸载后重新安装）

#### Scenario: 待生效时显示 warning 横幅
- **WHEN** `helperStatus` 为 `.pendingActivation`
- **THEN** 主窗口顶部显示浅黄色 warning 横幅，图标为黄色感叹号，并提示需要开启后台运行开关

#### Scenario: Helper 未安装时显示 warning 横幅
- **WHEN** `helperStatus` 为 `.notInstalled`、`.needUpgrade` 或 `.notCompatible`
- **THEN** 主窗口顶部显示浅黄色 warning 横幅，附带"前往设置"按钮

#### Scenario: SMJobBless 已安装时显示 info 横幅
- **WHEN** macOS 14+ 上 `activeMethod` 为 `.smJobBless` 且 `helperStatus` 为 `.installed`
- **THEN** 主窗口顶部显示浅蓝色 info 横幅，提示可升级到 SMAppService，附带"前往设置"按钮

#### Scenario: SMAppService 已安装时不显示横幅
- **WHEN** `activeMethod` 为 `.smAppService` 且 `helperStatus` 为 `.installed`
- **THEN** 主窗口顶部不显示任何横幅

#### Scenario: macOS 12–13 上 SMJobBless 已安装时不显示 info 横幅
- **WHEN** macOS 12–13 上 `activeMethod` 为 `.smJobBless` 且 `helperStatus` 为 `.installed`
- **THEN** 不显示 info 横幅（macOS 12–13 无 SMAppService 可用）
