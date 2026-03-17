## Context

项目当前使用 SMJobBless 机制安装 privileged helper（`cn.magicdian.staticrouter.helper`）。SMJobBless 要求主 app 和 helper 之间通过 requirement string 互相验证身份，现有配置将验证条件绑定到特定的 `Apple Development` 证书 CN（`DIAN JING (9X3RC5Q3Z4)`）。

该证书已被 revoke，Keychain 中同时存在有效和 revoked 两个同名证书，导致 Xcode 自动签名时可能选中 revoked 版本，macOS 将结果视为恶意软件拒绝启动。

项目现有签名配置混乱：helper target 的默认 `CODE_SIGN_IDENTITY = "-"`（ad-hoc），但 `sdk=macosx*` 覆盖为 `"Apple Development"`；主 app Debug 配置同样如此，Release 配置已为 `"-"`。需要全面统一。

## Goals / Non-Goals

**Goals:**
- 所有 target、所有 configuration 统一使用 ad-hoc 签名（`-`），消除对任何证书的依赖
- 将 SMJobBless 的 requirement string 改为仅验证 bundle identifier，解除证书绑定
- 版本号升至 1.3.2 记录此次变更

**Non-Goals:**
- 重新申请 Apple 开发者证书
- 修改 helper 的功能逻辑
- 修改 GitHub Actions workflow（已是 ad-hoc，无需变动）

## Decisions

### D1：`CODE_SIGN_STYLE = Manual`，`CODE_SIGN_IDENTITY = "-"`

将签名方式从 `Automatic` 改为 `Manual` + ad-hoc，阻止 Xcode 在 Automatic 模式下自动联系 Apple 服务器选择证书。`"-"` 是 `codesign` 的 ad-hoc 标识符，表示用二进制自身 hash 签名，无需任何 certificate。

`CODE_SIGN_IDENTITY[sdk=macosx*]` 覆盖项也须同步改为 `"-"`，否则 macOS SDK 构建仍会走 `Apple Development` 路径。

*备选方案*：保留 Automatic 并从 Keychain 删除 revoked 证书。拒绝理由：Keychain 状态是开发环境问题，项目配置本身不应依赖 Keychain 中特定证书的存在，ad-hoc 是更可移植的方案。

### D2：`DEVELOPMENT_TEAM = ""`（清空）

Automatic 模式下 Xcode 用 team ID 查找证书；Manual + ad-hoc 不需要 team，保留非空值会引起 Xcode 警告并可能触发不必要的网络请求。

### D3：SMJobBless requirement string 改为 identifier-only

将：
```
identifier "cn.magicdian.staticrouter.helper" and anchor apple generic and certificate leaf[subject.CN] = "Apple Development: DIAN JING (9X3RC5Q3Z4)"...
```
改为：
```
identifier "cn.magicdian.staticrouter.helper"
```

SMJobBless 在安装 helper 时会用 `SecRequirementEvaluate` 验证这个字符串。ad-hoc 签名的二进制没有证书链，`anchor apple generic` 条件必然失败。仅保留 identifier 条件后，验证只检查 bundle ID 是否匹配，ad-hoc 签名可以通过。

`SMAuthorizedClients`（在 helper 的 Info.plist 中）同理，改为仅验证主 app 的 identifier：
```
identifier "cn.magicdian.staticrouter"
```

*安全分析*：任何人都可以打包一个同 identifier 的二进制。对于本项目（开源、个人工具、无敏感数据访问），这个风险可接受。helper 的功能是配置路由表，攻击者若能在用户机器上安装任意 helper，通常已有更直接的提权手段。

## Risks / Trade-offs

- **[安全] identifier-only requirement 降低了 helper 的身份验证强度** → 对开源个人工具可接受；生产环境应使用 Developer ID
- **[兼容性] Hardened Runtime + ad-hoc 签名** → 项目已启用 `ENABLE_HARDENED_RUNTIME = YES`，ad-hoc 签名在本机运行时兼容，但部分 entitlement（如 JIT）在没有证书的情况下无法使用——本项目不涉及
- **[分发] 用户仍需 `xattr -cr`** → 已在 README 中文档化，无变化

## Migration Plan

1. 修改 `project.pbxproj` 中所有 build configuration 的签名设置
2. 修改两个 `Info.plist` 的 requirement string
3. 更新版本号
4. 在本地执行 `sudo launchctl bootout` + 删除旧 helper 文件（手动，开发者操作）
5. 重新 build，验证 SMJobBless 能用新 requirement string 安装 helper 并正常运行

**Rollback**：还原 `project.pbxproj` 和两个 `Info.plist` 的修改，重新签名即可。
