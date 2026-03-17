## 1. 创建脚本文件与目录

- [x] 1.1 在项目根目录创建 `scripts/` 目录
- [x] 1.2 创建 `scripts/bump-version.sh` 文件，设置 shebang 为 `#!/bin/bash` 并添加脚本说明注释（用途、参数、依赖工具）

## 2. 实现参数校验

- [x] 2.1 检查参数数量，若未提供参数则打印用法说明（`Usage: bump-version.sh <MARKETING_VERSION>`）并以退出码 1 退出
- [x] 2.2 使用正则校验参数格式为 `X.Y.Z`（三段纯数字），不合法则打印格式错误提示并以退出码 1 退出
- [x] 2.3 检查 `git rev-list` 命令是否可用（确认在 git 仓库中），失败则打印错误提示并以退出码 1 退出

## 3. 实现版本号读取与计算

- [x] 3.1 读取 pbxproj 中当前的 `MARKETING_VERSION` 值（用 `grep` + 提取）作为旧版本号，用于摘要输出
- [x] 3.2 读取 pbxproj 中当前的 `CURRENT_PROJECT_VERSION` 值作为旧 build number，用于摘要输出
- [x] 3.3 通过 `git rev-list --count HEAD` 计算新的 `CURRENT_PROJECT_VERSION`

## 4. 实现 pbxproj 修改

- [x] 4.1 使用 BSD `sed -i ''` 将 pbxproj 中所有 `CURRENT_PROJECT_VERSION = <旧值>;` 替换为新值
- [x] 4.2 使用 BSD `sed -i ''` 将 pbxproj 中所有 `MARKETING_VERSION = <旧值>;` 替换为新值

## 5. 打印操作摘要与验证

- [x] 5.1 替换完成后打印摘要，格式为：
  ```
  Version: <旧> → <新>
  Build:   <旧> → <新>
  ```
- [x] 5.2 手动执行脚本（`./scripts/bump-version.sh 1.5.0`），验证输出摘要正确
- [x] 5.3 用 `grep` 确认 pbxproj 中 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION` 均已更新为新值，无旧值残留
- [x] 5.4 设置脚本可执行权限（`chmod +x scripts/bump-version.sh`）
