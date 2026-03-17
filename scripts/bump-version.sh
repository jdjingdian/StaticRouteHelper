#!/bin/bash
#
# bump-version.sh
#
# 用途：更新 StaticRouteHelper 项目的版本号
#       将 MARKETING_VERSION 和 CURRENT_PROJECT_VERSION 写入 project.pbxproj
#
# 用法：./scripts/bump-version.sh <MARKETING_VERSION>
#   例：./scripts/bump-version.sh 1.5.0
#
# 参数：
#   MARKETING_VERSION  新版本号，格式必须为 X.Y.Z（三段纯数字）
#
# 依赖工具（均为 macOS 系统内置）：
#   git   — 计算 CURRENT_PROJECT_VERSION（commit 总数）
#   sed   — BSD sed，原地修改 project.pbxproj
#   grep  — 读取当前版本值
#
# 注意：本脚本使用 BSD sed（macOS 内置），与 GNU sed 不兼容。
#       请在 macOS 开发机上运行，不要在 Linux CI 环境中直接使用。

set -euo pipefail

# ---------------------------------------------------------------------------
# 路径定位：脚本始终相对于仓库根目录操作
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PBXPROJ="${REPO_ROOT}/StaticRouteHelper.xcodeproj/project.pbxproj"

# ---------------------------------------------------------------------------
# 参数校验 (Tasks 2.1 & 2.2)
# ---------------------------------------------------------------------------
if [[ $# -eq 0 ]]; then
    echo "Error: MARKETING_VERSION is required."
    echo ""
    echo "Usage: $(basename "$0") <MARKETING_VERSION>"
    echo "  e.g. $(basename "$0") 1.5.0"
    exit 1
fi

NEW_MARKETING_VERSION="$1"

if ! [[ "${NEW_MARKETING_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid version format '${NEW_MARKETING_VERSION}'."
    echo "       MARKETING_VERSION must be in X.Y.Z format (e.g. 1.5.0)."
    exit 1
fi

# ---------------------------------------------------------------------------
# Git 仓库检查 (Task 2.3)
# ---------------------------------------------------------------------------
if ! git -C "${REPO_ROOT}" rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not inside a git repository. Cannot compute CURRENT_PROJECT_VERSION."
    exit 1
fi

# ---------------------------------------------------------------------------
# 读取当前版本值 (Tasks 3.1 & 3.2)
# ---------------------------------------------------------------------------
# 使用精确 pattern 匹配 build setting 赋值行（`= 数字;`），
# 避免匹配到 build phase shell script 里的 ${CURRENT_PROJECT_VERSION} 变量引用
OLD_MARKETING_VERSION=$(grep -m1 'MARKETING_VERSION = [0-9]' "${PBXPROJ}" | sed 's/.*MARKETING_VERSION = \(.*\);/\1/' | tr -d '[:space:]')
OLD_BUILD_NUMBER=$(grep -m1 'CURRENT_PROJECT_VERSION = [0-9]' "${PBXPROJ}" | sed 's/.*CURRENT_PROJECT_VERSION = \(.*\);/\1/' | tr -d '[:space:]')

# ---------------------------------------------------------------------------
# 计算新 build number (Task 3.3)
# ---------------------------------------------------------------------------
NEW_BUILD_NUMBER=$(git -C "${REPO_ROOT}" rev-list --count HEAD)

# ---------------------------------------------------------------------------
# 修改 pbxproj (Tasks 4.1 & 4.2)
# ---------------------------------------------------------------------------
# 使用通用 pattern（匹配任意数字值），不依赖旧值字符串，
# 避免旧值含特殊字符时 BSD sed 报错。
# BSD sed: -i '' means in-place edit with no backup
sed -i '' 's/CURRENT_PROJECT_VERSION = [0-9][0-9]*;/CURRENT_PROJECT_VERSION = '"${NEW_BUILD_NUMBER}"';/g' "${PBXPROJ}"
sed -i '' 's/MARKETING_VERSION = [0-9][0-9.]*;/MARKETING_VERSION = '"${NEW_MARKETING_VERSION}"';/g' "${PBXPROJ}"

# ---------------------------------------------------------------------------
# 打印操作摘要 (Task 5.1)
# ---------------------------------------------------------------------------
echo ""
echo "Version bump complete:"
echo "  Version: ${OLD_MARKETING_VERSION} -> ${NEW_MARKETING_VERSION}"
echo "  Build:   ${OLD_BUILD_NUMBER} -> ${NEW_BUILD_NUMBER}"
echo ""
echo "Next steps:"
echo "  1. Review the diff: git diff StaticRouteHelper.xcodeproj/project.pbxproj"
echo "  2. Commit and tag:  git add -A && git commit -m \"Bump version to ${NEW_MARKETING_VERSION}\""
echo "  3. Create release:  git tag v${NEW_MARKETING_VERSION} && git push origin v${NEW_MARKETING_VERSION}"
