## 1. HelperToolMonitor 健壮性修复

- [x] 1.1 在 `HelperToolMonitor.start(changeOccurred:)` 中为每个监控目录添加 `open` 返回值校验，仅在 `fd >= 0` 时创建 `DispatchSource`。
- [x] 1.2 为 `open` 失败路径增加日志与统计（至少记录目录路径、errno、是否触发降级），并确保失败目录不会写入 `dispatchSources`。
- [x] 1.3 调整 `start/stop` 生命周期为幂等：重复 `start` 不重复注册，`stop` 仅取消已创建 source 并清理映射。
- [x] 1.4 让 `start` 暴露可用监听源结果（数量或布尔值），供 `RouterService` 判定是否启用降级策略。

## 2. RouterService 启动降级与状态兜底

- [x] 2.1 在 `RouterService.init()` 接入 `HelperToolMonitor.start` 的返回结果，监听不可用时仍完成初始化，不触发 fatal 行为。
- [x] 2.2 增加低频 helper 状态刷新兜底任务（例如 5-10 秒），仅在监听不可用时启用。
- [x] 2.3 在应用重新激活时触发一次即时 `refreshState`，减少轮询带来的状态延迟。
- [x] 2.4 确保降级刷新与现有 `helperManager` publisher 更新不冲突（避免重复写状态和竞态）。

## 3. 测试与回归验证

- [ ] 3.1 新增/更新单元测试：`open` 失败时 `HelperToolMonitor.start` 不崩溃且返回“不可用监听”状态。
- [ ] 3.2 新增/更新单元测试：部分目录失败时仍创建可用 source，`stop` 后资源被正确清理。
- [ ] 3.3 新增/更新集成测试或可替代验证：`RouterService` 在监听不可用时仍可初始化并持续刷新 `helperStatus`。
- [ ] 3.4 手工回归 macOS 13.4：验证冷启动不崩溃、安装/卸载 helper 后状态可在预期时间内更新。
