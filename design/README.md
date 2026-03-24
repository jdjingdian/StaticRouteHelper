# StaticRouteHelper Design Docs

本目录用于沉淀当前版本 UI 设计风格与实现规范，作为后续迭代的统一参考。

## 文档列表

- `STYLE_GUIDE.md`：主视觉语言、颜色与组件规范、交互/可访问性规范、页面级落地规则。

## 适用范围

- macOS SwiftUI 客户端（`StaticRouter` 目标）。
- 当前已落地页面：主窗口、侧边栏、系统路由表、设置（通用/关于）、路由编辑弹窗。

## 维护方式

- 若调整设计 token（颜色、圆角、间距、动效时长），先更新 `STYLE_GUIDE.md`，再改代码。
- 若新增页面，先按 `STYLE_GUIDE.md` 建立页面结构，再写具体业务控件。
