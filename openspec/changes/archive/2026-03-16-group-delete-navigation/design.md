## Context

`SidebarView` 通过 `@Binding var selection: SidebarItem?` 与父视图共享导航状态。删除分组时，`deleteGroup(_:)` 仅执行数据层操作（解除关联、删除模型、保存），不感知当前 `selection`，导致被删除分组的视图残留在内容区。

当前 `deleteGroup(_:)` 是一个私有函数，无法访问 `selection` 绑定；需要在执行删除后，若删除目标与当前 `selection` 匹配，则将 `selection` 重置为 `.allRoutes`。

## Goals / Non-Goals

**Goals:**
- 删除当前选中分组后，`selection` 自动切换到 `.allRoutes`。
- 删除非当前选中分组时，`selection` 保持不变。
- 修改范围最小化，仅影响 `SidebarView.swift`。

**Non-Goals:**
- 不修改删除的数据逻辑（解除关联、delete、save）。
- 不处理多选删除（当前 UI 不支持）。
- 不引入新的状态管理层或 ViewModel。

## Decisions

**Decision 1: 在 `deleteGroup(_:)` 内直接比较并重置 `selection`**

`deleteGroup` 已可访问 `selection`（同为 `SidebarView` 的成员）。在数据删除完成后，执行：

```swift
if case .group(let selected) = selection, selected.id == group.id {
    selection = .allRoutes
}
```

- 放在 `modelContext.delete(group)` 之后、`save()` 之前或之后均可，顺序不影响 UI 正确性。
- 无需额外状态、无需 DispatchQueue 延迟——SwiftUI 的 `@Binding` 更新会在下一渲染周期生效，此时模型已被删除，`List` 自然不再渲染该行。

*备选方案*：在 alert 的确认回调中直接写导航逻辑，但这会将逻辑分散，不如集中在 `deleteGroup` 内内聚。

**Decision 2: 使用 `group.id` 比较而非引用相等**

被删除前 `group` 对象仍有效，`SidebarItem.group(group)` 中存储的是同一 `RouteGroup` 实例，可以直接用 `id`（`PersistentIdentifier`）比较，确保跨 SwiftData 生命周期的稳定匹配。

## Risks / Trade-offs

- [Risk] SwiftData 删除后对象引用变为无效状态，若先重置 `selection` 再删除，理论上无影响；若先删除再比较 `id`，对象可能已被 invalidate。→ **Mitigation**: 在 `modelContext.delete(group)` 之前先读取并缓存需要比较的 `id`，或直接在删除前比较（顺序：比较→删除→save）。
- [Risk] 未来若引入批量删除，此逻辑需扩展为遍历所有被删除分组判断。→ 当前单条删除无此问题，记录为已知限制。
