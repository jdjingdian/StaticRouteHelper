### Requirement: 所有 target 使用 ad-hoc 签名
项目中所有 target（主 app `Static Router` 和 helper `cn.magicdian.staticrouter.helper`）的所有 build configuration（Debug 和 Release）SHALL 使用 ad-hoc 签名（`CODE_SIGN_IDENTITY = "-"`，`CODE_SIGN_STYLE = Manual`），不依赖任何开发者证书。

#### Scenario: 无证书环境下本地 build 成功
- **WHEN** 开发者 Keychain 中没有任何有效的 Apple Development 证书
- **THEN** `xcodebuild` SHALL 成功编译并生成签名的 `.app` bundle
- **THEN** 编译过程 SHALL NOT 报告证书相关错误

#### Scenario: revoked 证书不影响构建
- **WHEN** Keychain 中存在 revoked 状态的 `Apple Development` 证书
- **THEN** 构建 SHALL NOT 使用该 revoked 证书签名
- **THEN** 生成的 binary SHALL 使用 ad-hoc 签名

#### Scenario: CI 环境 build 成功
- **WHEN** GitHub Actions macOS runner（无任何开发者证书）执行构建
- **THEN** `xcodebuild` SHALL 成功完成，产出可被 ad-hoc 签名的 `.app`

### Requirement: DEVELOPMENT_TEAM 清空
`project.pbxproj` 中所有 build configuration 的 `DEVELOPMENT_TEAM` SHALL 为空字符串，避免 Xcode 尝试解析团队证书。

#### Scenario: 无网络访问时 Xcode 不因 team 报错
- **WHEN** 开发机没有网络连接时打开项目
- **THEN** Xcode SHALL NOT 显示"无法连接到开发者服务"类型的签名错误
