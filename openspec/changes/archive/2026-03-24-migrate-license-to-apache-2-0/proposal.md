## 为什么

项目仓库的 `LICENSE` 已切换为 Apache 2.0，但代码库中的用户可见文案仍有 GPLv3 表述。许可证声明不一致会造成合规风险与用户理解偏差，因此需要尽快统一。

## 变更内容

- 将项目内所有面向用户/开发者的 GPLv3 声明更新为 Apache 2.0。
- 统一中英文 README 的许可证章节文案与链接。
- 统一应用内 About 页面本地化资源中的许可证描述。
- 对仓库进行一次许可证文案扫描，确保不存在遗留 GPLv3 项目声明。

## 功能 (Capabilities)

### 新增功能
- `project-license-disclosure`: 定义项目许可证对外披露的一致性要求，确保 README 与应用内文案与 `LICENSE` 文件一致。

### 修改功能
- 无

## 影响

- 文档：`README.md`、`README_CN.md`
- 资源：`Resources/Locale/en.lproj/Localizable.strings`、`Resources/Locale/zh-Hans.lproj/Localizable.strings`
- 合规认知：用户与贡献者读取到的许可证信息将与仓库根目录 `LICENSE` 一致
