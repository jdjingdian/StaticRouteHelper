## 1. 状态刷新策略

- [x] 1.1 在 `PrivilegedHelperManager` 中抽取可复用的轮询调度逻辑，保留现有 10 秒低频监听作为基线。
- [x] 1.2 增加“安装后短时快速刷新窗口”能力（间隔与持续时长常量化，默认 500ms / 3s）。
- [x] 1.3 在 SMJobBless 与 SMAppService 安装成功路径接入快速刷新窗口，并确保窗口结束后自动回退基线策略。
- [x] 1.4 为刷新窗口增加最小日志或调试标记，便于验证安装后状态更新时间。
- [x] 1.5 修复 SMJobBless 卸载 XPC 响应竞态，避免点击卸载后界面无反馈或状态迟滞。
- [x] 1.6 为 SMJobBless 卸载 XPC 增加超时保护并自动回退 osascript，避免请求悬挂。
- [x] 1.7 为 SMJobBless 卸载增加结果落地校验；XPC 返回成功但状态未收敛时自动回退 osascript。
- [x] 1.8 调整卸载收敛窗口参数，避免正常慢路径被过早判定为失败而频繁触发回退。
- [x] 1.9 修正 helper 自卸载实现（优先 bootout，兼容 unload），降低“XPC 成功但实际未卸载”概率。
- [x] 1.10 修复回退失败时的重复兜底调用，避免连续两次弹出管理员授权。
- [x] 1.11 增强 helper 自卸载关键日志并引入可调 XPC 超时窗口，便于定位超时与落地失败。
- [x] 1.12 修正 helper target Debug 编译条件，确保 `HELPER` 宏在调试构建生效。
- [x] 1.13 修正 SMJobBless launchd plist 为 `ProgramArguments` 形式，避免安装后 job 不可达。
- [x] 1.14 将 helper 自卸载改为同进程延迟执行，避免子进程竞态导致落地失败。
- [x] 1.15 简化 helper 自卸载步骤为直接删除 blessed artifacts，提升收敛确定性。

## 2. 设置页待生效引导入口

- [x] 2.1 在 `GeneralSettings_HelperStateView` 中为待生效状态增加“打开系统设置”按钮。
- [x] 2.2 将按钮动作统一为调用 `SMAppService.openSystemSettingsLoginItems()`，并处理 macOS 可用性判断。
- [x] 2.3 调整视图显示条件，使入口仅由待生效真实状态驱动，不依赖弹窗是否被取消。

## 3. 文案与验证

- [x] 3.1 补充或更新本地化键（按钮标题/辅助说明），确保中文与英文资源一致。
- [ ] 3.2 手动验证：SMJobBless 安装后状态在短时间内更新；待生效时取消弹窗后仍可通过按钮跳转系统设置。
- [ ] 3.3 回归验证：macOS 12–13 安装/卸载流程不受影响，且不出现无效设置跳转入口。

## 4. 通道隔离与稳定性

- [x] 4.1 为 SMAppService 新增独立 launchd plist（`cn.magicdian.staticrouter.service.plist`），拆分 label/mach service。
- [x] 4.2 更新打包清单与共享常量，分离 SMJobBless/SMAppService 通道元数据。
- [x] 4.3 在 App 侧按 `activeMethod` 选择 XPC 客户端，避免跨通道复用。
- [x] 4.4 加入 SMJobBless 安装后收敛校验，识别并阻断 SMAppService 抢占场景。
- [x] 4.5 通过实机日志验证：拆分后后台开关不再影响 SMJobBless 进程判定。
- [x] 4.6 通过实机日志验证：SMJobBless 卸载可在 XPC 主路径收敛，默认不再触发 osascript 回退。
