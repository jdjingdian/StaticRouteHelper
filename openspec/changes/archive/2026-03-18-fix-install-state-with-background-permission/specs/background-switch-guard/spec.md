## MODIFIED Requirements

### Requirement: 安装/卸载前后台开关检查
在 macOS 14+ 上，执行 SMAppService 安装操作前，系统 SHALL 检查 `SMAppService.daemon(...).status`。若状态为 `.requiresApproval`（表示后台运行开关关闭），系统 SHALL 阻断重复安装并弹出引导弹窗。对于 SMJobBless 安装操作，系统 SHALL 在 `authorizeAndBless()` 失败时同样弹出引导弹窗。

对于卸载操作，系统 SHALL 区分状态处理：
1. 若当前状态为“待生效”（`pendingActivation`，表示已安装但未获后台授权），系统 SHALL 允许卸载，不要求先开启后台开关。
2. 待生效状态下的卸载 SHALL 通过 `osascript` 路径执行，确保可在 `.requiresApproval` 条件下完成清理。

#### Scenario: SMAppService 安装时开关关闭
- **WHEN** 用户在 macOS 14+ 上选择 SMAppService 安装，但后台运行开关处于关闭状态
- **THEN** 系统不执行 `register()`，弹出引导弹窗说明需要开启后台运行开关

#### Scenario: 待生效状态下卸载放行
- **WHEN** 用户尝试卸载已处于 `pendingActivation` 的 Helper，且后台运行开关关闭
- **THEN** 系统允许卸载并通过 `osascript` 执行卸载流程

#### Scenario: SMJobBless 安装时系统限制
- **WHEN** 用户在 macOS 14+ 上选择 SMJobBless 安装，`authorizeAndBless()` 因系统限制失败
- **THEN** 系统弹出引导弹窗，引导用户检查系统设置

#### Scenario: 开关已开启时正常操作
- **WHEN** 用户执行安装/卸载操作，后台运行开关处于开启状态
- **THEN** 操作正常执行，不弹出引导弹窗
