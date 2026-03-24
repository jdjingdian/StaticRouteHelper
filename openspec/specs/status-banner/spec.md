## ADDED Requirements

### Requirement: 通用 StatusBanner 组件
系统 SHALL 提供一个通用的 `StatusBanner` View 组件，替代现有的 `HelperNotInstalledBanner`。组件 SHALL 接受以下参数：
- `style: BannerStyle` — 决定背景色和图标颜色
- `message: LocalizedStringKey` — 横幅消息文本
- `actionLabel: LocalizedStringKey` — 操作按钮文本
- `action: () -> Void` — 操作按钮回调

布局 SHALL 为：图标 + 消息文本 + Spacer + 操作按钮，底部带 Divider，与现有 `HelperNotInstalledBanner` 布局一致。

#### Scenario: warning 样式渲染
- **WHEN** `StatusBanner` 以 `.warning` 样式显示
- **THEN** 背景色为 `.yellow.opacity(0.12)`，图标为 `exclamationmark.triangle.fill`（黄色），与现有 HelperNotInstalledBanner 视觉一致

#### Scenario: info 样式渲染
- **WHEN** `StatusBanner` 以 `.info` 样式显示
- **THEN** 背景色为 `.blue.opacity(0.12)`，图标为 `info.circle.fill`（蓝色）

### Requirement: 主窗口横幅显示逻辑
主窗口详情区域顶部 SHALL 根据以下条件按优先级显示一个横幅（互斥，只显示最高优先级）：

1. **优先级 1** — `helperStatus == .pendingActivation`：显示 `.warning` 横幅，消息提示 Helper 已安装但待生效（需开启后台运行开关），按钮引导到设置页
2. **优先级 2** — `helperStatus != .installed` 且 `helperStatus != .pendingActivation`：显示 `.warning` 横幅，消息提示 Helper 未安装，按钮引导到设置页
3. **优先级 3** — macOS 14+ 且 `activeMethod == .smJobBless` 且 `helperStatus == .installed`：显示 `.info` 横幅，消息提示有更现代的部署方式可用，按钮引导到设置页（卸载后重新安装）

横幅中的“前往设置”按钮 SHALL 与 Sidebar 设置按钮复用同一设置导航策略，确保在 macOS 12–14+ 上均可用，且行为一致。

#### Scenario: 待生效时显示 warning 横幅
- **WHEN** `helperStatus` 为 `.pendingActivation`
- **THEN** 主窗口顶部显示浅黄色 warning 横幅，图标为黄色感叹号，并提示需要开启后台运行开关

#### Scenario: Helper 未安装时显示 warning 横幅
- **WHEN** `helperStatus` 为 `.notInstalled`、`.needUpgrade` 或 `.notCompatible`
- **THEN** 主窗口顶部显示浅黄色 warning 横幅，附带"前往设置"按钮

#### Scenario: SMJobBless 已安装时显示 info 横幅
- **WHEN** macOS 14+ 上 `activeMethod` 为 `.smJobBless` 且 `helperStatus` 为 `.installed`
- **THEN** 主窗口顶部显示浅蓝色 info 横幅，提示可升级到 SMAppService，附带"前往设置"按钮

#### Scenario: macOS 13 点击横幅“前往设置”
- **WHEN** 用户在 macOS 13 点击横幅中的“前往设置”
- **THEN** 设置窗口被成功打开，不得出现点击无响应

#### Scenario: SMAppService 已安装时不显示横幅
- **WHEN** `activeMethod` 为 `.smAppService` 且 `helperStatus` 为 `.installed`
- **THEN** 主窗口顶部不显示任何横幅

#### Scenario: macOS 12–13 上 SMJobBless 已安装时不显示 info 横幅
- **WHEN** macOS 12–13 上 `activeMethod` 为 `.smJobBless` 且 `helperStatus` 为 `.installed`
- **THEN** 不显示 info 横幅（macOS 12–13 无 SMAppService 可用）
