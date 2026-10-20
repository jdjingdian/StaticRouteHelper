//
//  AppStoreUpdateController.swift
//  StaticRouteHelper
//
//  App Store 分发渠道的更新检查器（预留）。
//
//  App Store 版本的应用内更新提示计划接入 Siren
//  （https://github.com/ArtSabintsev/Siren，按上架规则提醒用户去 App Store
//  更新）；接入前本实现为占位，不执行任何动作。
//
//  注意：App Store 版本必须使用开发者团队签名，且特权助手（SMJobBless/
//  SMAppService）无法随 App Store 包安装——上架前需要先完成特权能力迁移
//  （如改用用户级 launch agent + 授权提示）。在该前提就绪前此渠道不会被启用。
//

import Foundation

final class AppStoreUpdateController: UpdateChecking {

    /// Siren 未接入前置为 false；接入后改为 true 并实现两个检查方法
    let isSupported = false

    func checkForUpdates() {
        // TODO: 接入 Siren 后由其触发
    }

    func checkForUpdatesInBackground() {
        // TODO: 接入 Siren 后由其触发
    }
}
