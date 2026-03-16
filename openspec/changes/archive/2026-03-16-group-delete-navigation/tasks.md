## 1. 修改 SidebarView — 导航重置逻辑

- [x] 1.1 在 `deleteGroup(_:)` 函数内，执行 `modelContext.delete(group)` 之前，判断当前 `selection` 是否为该分组（`case .group(let selected) = selection, selected.id == group.id`）
- [x] 1.2 若匹配，在删除并保存后将 `selection` 重置为 `.allRoutes`

## 2. 验证

- [x] 2.1 运行 App，创建至少两个分组，选中其中一个，通过右键菜单删除该分组 → 确认内容区跳转到"所有路由"，侧栏无残留
- [x] 2.2 选中分组 A，右键删除非选中的分组 B → 确认 selection 保持在分组 A，内容区不变
- [x] 2.3 触发删除弹窗后点"取消" → 确认分组及选中状态均不变
