## 1. project.pbxproj 签名配置

- [x] 1.1 将 helper target（Debug）的 `CODE_SIGN_IDENTITY[sdk=macosx*]` 从 `"Apple Development"` 改为 `"-"`
- [x] 1.2 将 helper target（Debug）的 `CODE_SIGN_STYLE` 从 `Automatic` 改为 `Manual`
- [x] 1.3 将 helper target（Debug）的 `DEVELOPMENT_TEAM` 清空（`= ""`）
- [x] 1.4 将 helper target（Release）的 `CODE_SIGN_IDENTITY[sdk=macosx*]` 从 `"Apple Development"` 改为 `"-"`
- [x] 1.5 将 helper target（Release）的 `CODE_SIGN_STYLE` 从 `Automatic` 改为 `Manual`
- [x] 1.6 将 helper target（Release）的 `DEVELOPMENT_TEAM` 清空
- [x] 1.7 将主 app target（Debug）的 `CODE_SIGN_IDENTITY` 和 `CODE_SIGN_IDENTITY[sdk=macosx*]` 均改为 `"-"`
- [x] 1.8 将主 app target（Debug）的 `CODE_SIGN_STYLE` 从 `Automatic` 改为 `Manual`
- [x] 1.9 将主 app target（Debug）的 `DEVELOPMENT_TEAM` 清空
- [x] 1.10 将主 app target（Release）的 `CODE_SIGN_IDENTITY[sdk=macosx*]` 改为 `"-"`（Release 已是 `"-"`，确认无遗漏）
- [x] 1.11 将主 app target（Release）的 `CODE_SIGN_STYLE` 从 `Automatic` 改为 `Manual`
- [x] 1.12 将主 app target（Release）的 `DEVELOPMENT_TEAM` 清空

## 2. SMJobBless Requirement String

- [x] 2.1 修改 `StaticRouter/Info.plist` 中 `SMPrivilegedExecutables` 的 requirement string 为 `identifier "cn.magicdian.staticrouter.helper"`
- [x] 2.2 修改 `RouteHelper/Info.plist` 中 `SMAuthorizedClients` 的 requirement string 为 `identifier "cn.magicdian.staticrouter"`

## 3. 版本号更新

- [x] 3.1 将 `project.pbxproj` 中所有 `CURRENT_PROJECT_VERSION` 从 `1.3.1` 改为 `1.3.2`
- [x] 3.2 将 `project.pbxproj` 中所有 `MARKETING_VERSION` 从 `1.3.1` 改为 `1.3.2`

## 4. 验证

- [ ] 4.1 在 Xcode 中 clean build（⇧⌘K 后 ⌘B），确认无签名相关错误
- [ ] 4.2 运行 app，确认 SMJobBless 成功安装 helper（首次运行会弹出授权对话框）
- [ ] 4.3 确认路由功能正常（添加/删除路由）
