## Why

开发者证书被 revoke 后，Keychain 中残留的 revoked 证书导致 Xcode 使用无效签名构建，macOS 将 privileged helper 识别为恶意软件并拒绝启动整个应用。同时，SMJobBless 的 requirement string 硬编码了证书 CN，使得 ad-hoc 签名完全无法通过运行时验证，分发场景和本地开发都受影响，需要彻底切换到不依赖具体证书身份的签名方案。

## What Changes

- 将 Xcode 项目中主 app 及 helper 两个 target 的所有配置（Debug/Release）统一改为 ad-hoc 签名（`CODE_SIGN_IDENTITY = "-"`），移除对 `Apple Development` 身份的依赖
- 将 `CODE_SIGN_STYLE` 从 `Automatic` 改为 `Manual`，阻止 Xcode 自动选择证书
- 清空 `DEVELOPMENT_TEAM`，避免 Xcode 尝试联系 Apple 服务器验证团队证书
- 修改 `StaticRouter/Info.plist` 中的 `SMPrivilegedExecutables` requirement string，从证书 CN 验证改为仅验证 bundle identifier
- 修改 `RouteHelper/Info.plist` 中的 `SMAuthorizedClients` requirement string，同样改为仅验证 bundle identifier
- 将 `CURRENT_PROJECT_VERSION` 和 `MARKETING_VERSION` 从 `1.3.1` 升级到 `1.3.2`

## Capabilities

### New Capabilities

- `adhoc-codesign-config`: Xcode 项目构建时使用 ad-hoc 签名，无需任何开发者证书即可本地编译和运行
- `identifier-only-smbless-requirement`: SMJobBless 的双向 requirement string 仅验证 bundle identifier，不验证证书身份

### Modified Capabilities

<!-- 无现有 spec 级别的行为变更 -->

## Impact

- **修改文件**：`StaticRouteHelper.xcodeproj/project.pbxproj`、`StaticRouter/Info.plist`、`RouteHelper/Info.plist`
- **版本号**：1.3.1 → 1.3.2
- **安全影响**：SMJobBless requirement 放宽后，任何同 identifier 的 helper 均可被安装——对于开源工具可接受，但不适合需要严格安全边界的场景
- **CI 影响**：与现有 GitHub Actions ad-hoc 签名流程一致，无需额外修改 workflow
