## Why

当前 Helper 安装状态仅区分“已安装/未安装”，导致 macOS 后台运行开关关闭（`SMAppService.status == .requiresApproval`）时被误判为未安装。用户点击安装后即使安装成功，也无法看到“待生效”中间态，且无法在该状态下执行卸载，造成状态认知和操作路径不一致。

## What Changes

- 新增“待生效”状态语义：当 Helper 已安装但后台运行开关关闭时，状态显示为待生效（黄色感叹号），不再显示为未安装。
- 调整安装后状态流转：点击安装且安装流程无报错后，若检测到后台开关关闭，界面进入待生效状态。
- 调整卸载策略：在待生效状态允许卸载，不再要求必须先开启后台开关。
- 增加待生效状态下的卸载实现约束：在该路径下通过 `osascript` 执行卸载流程，确保用户可恢复到未安装状态。
- 更新状态横幅与提示文案，使“未安装”与“待生效”在 UI 上有明确区分。

## Capabilities

### New Capabilities
- `pending-activation-state`: 定义 Helper 已安装但后台运行开关关闭时的待生效状态、展示规则与状态流转。

### Modified Capabilities
- `background-switch-guard`: 将“开关关闭时阻断卸载”改为“开关关闭时允许在待生效状态执行卸载”，并补充 `osascript` 卸载路径要求。
- `status-banner`: 增加待生效状态横幅/图标与优先级规则，避免将待生效误显示为未安装。

## Impact

- 受影响模块：`PrivilegedHelperManager` 状态判定与安装/卸载分支、`RouterService.helperStatus` 映射、设置页与主界面状态横幅。
- 受影响能力：macOS 14+ 的 SMAppService 状态识别、后台开关关闭时的交互引导与恢复路径。
- 技术依赖：新增或扩展 `osascript` 卸载调用能力；需要确保失败路径有可见错误反馈与日志。
