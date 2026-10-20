//
//  SparkleUpdateController.swift
//  StaticRouteHelper
//
//  GitHub Releases 分发渠道的更新检查器，基于 Sparkle 2。
//
//  更新流程由 Sparkle 标准用户驱动接管：检查（appcast，EdDSA 签名校验）→
//  下载（自动/进度 UI）→ 提示"安装并重启" → 自动替换重启。
//  appcast.xml 由 release.yml 在每次发版时生成并上传为 Release 资源，
//  稳定地址见 Info.plist 的 SUFeedURL（releases/latest/download/appcast.xml）。
//

import Foundation
import Sparkle

final class SparkleUpdateController: NSObject, UpdateChecking {

    /// 进程内唯一实例。
    /// SPUStandardUpdaterController 每创建一次就会启动一个独立的 updater 并触发
    /// 首次检查——多实例会导致同一更新弹出多个提示窗（且互相干扰无法关闭）。
    static let shared = SparkleUpdateController()

    let isSupported = true

    /// Sparkle 标准控制器：负责启动 updater 并挂接系统驱动
    private let updaterController: SPUStandardUpdaterController

    private override init() {
        // updaterDelegate/userDriverDelegate 暂无定制需求；需要拦截更新决策时再实现
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func checkForUpdates() {
        // 手动检查：标准驱动会展示"已是最新/新版本"对话框
        updaterController.checkForUpdates(nil)
    }

    func checkForUpdatesInBackground() {
        // 后台检查：仅在有新版本时提示，不打扰用户
        updaterController.updater.checkForUpdatesInBackground()
    }
}
