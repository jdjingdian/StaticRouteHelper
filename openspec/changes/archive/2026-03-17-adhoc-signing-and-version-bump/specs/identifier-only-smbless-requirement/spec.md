## ADDED Requirements

### Requirement: SMPrivilegedExecutables 仅验证 helper identifier
`StaticRouter/Info.plist` 中 `SMPrivilegedExecutables` 字典内 `cn.magicdian.staticrouter.helper` 对应的 requirement string SHALL 仅包含 identifier 条件，不包含任何证书或锚点条件。

#### Scenario: ad-hoc 签名 helper 通过 SMJobBless 安装
- **WHEN** 主 app 调用 SMJobBless 安装 ad-hoc 签名的 helper
- **THEN** macOS SHALL 验证 helper 的 bundle identifier 为 `cn.magicdian.staticrouter.helper`
- **THEN** 验证 SHALL 通过，helper SHALL 被成功安装到 `/Library/PrivilegedHelperTools/`

#### Scenario: identifier 不匹配时安装被拒
- **WHEN** 尝试安装 bundle identifier 不为 `cn.magicdian.staticrouter.helper` 的二进制
- **THEN** SMJobBless SHALL 拒绝安装

### Requirement: SMAuthorizedClients 仅验证主 app identifier
`RouteHelper/Info.plist` 中 `SMAuthorizedClients` 数组内的 requirement string SHALL 仅包含主 app 的 identifier 条件，不包含任何证书或锚点条件。

#### Scenario: ad-hoc 签名主 app 被 helper 接受
- **WHEN** ad-hoc 签名的主 app（identifier `cn.magicdian.staticrouter`）与 helper 建立 XPC 连接
- **THEN** helper SHALL 验证客户端 identifier 匹配
- **THEN** 连接 SHALL 成功建立

#### Scenario: 非授权客户端被拒绝
- **WHEN** identifier 不为 `cn.magicdian.staticrouter` 的进程尝试连接 helper
- **THEN** helper SHALL 拒绝该连接
