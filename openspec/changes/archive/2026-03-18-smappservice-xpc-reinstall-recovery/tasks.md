## 1. 服务层恢复信号与流程编排

- [x] 1.1 在 `RouterService` 增加可观察的“SMAppService XPC 可恢复失败”状态（包含错误消息与是否可自动重装）。
- [x] 1.2 在路由写入失败映射中补充触发条件：仅当 `activeMethod == .smAppService` 且 `isPendingApproval == false` 时标记为可恢复失败。
- [x] 1.3 增加自动重装入口方法，按顺序执行 `uninstallHelper()` 后 `installHelper(method: .smAppService)`，并在结束后刷新 helper 状态。
- [x] 1.4 为自动重装流程增加并发保护（进行中不重复触发）与步骤级错误回传（卸载失败/安装失败）。

## 2. UI 弹窗接入与推荐动作

- [x] 2.1 在 `RouteListView` 接入恢复弹窗状态绑定，接收 `RouterService` 的可恢复失败信号。
- [x] 2.2 在 `LegacyRouteListView` 接入同等恢复弹窗与动作，保持 macOS 12-13 路径一致。
- [x] 2.3 实现弹窗按钮：`取消` 关闭弹窗；`自动重装` 触发恢复流程并作为主/默认推荐动作。
- [x] 2.4 在恢复流程执行期间更新界面交互（禁用重复触发、结束后清理弹窗状态）。

## 3. 本地化与回归验证

- [x] 3.1 在 `Resources/Locale/zh-Hans.lproj/Localizable.strings` 新增恢复弹窗文案键（标题、说明、取消、自动重装、失败提示）。
- [x] 3.2 在 `Resources/Locale/en.lproj/Localizable.strings` 同步新增对应英文文案键。
- [x] 3.3 手动验证场景：SMAppService + XPC 失败时弹窗出现；取消无副作用；自动重装执行卸载后安装并刷新状态。
- [x] 3.4 回归验证场景：SMJobBless 路径与后台开关待授权场景不触发自动重装弹窗，维持原有错误与引导逻辑。
