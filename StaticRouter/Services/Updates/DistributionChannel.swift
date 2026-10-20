//
//  DistributionChannel.swift
//  StaticRouteHelper
//
//  应用分发渠道抽象：不同渠道使用不同的更新检查框架。
//
//  - .sparkleGitHub：GitHub Releases 直接分发，使用 Sparkle（appcast + EdDSA 签名）
//  - .appStore：App Store 分发，预留接入 Siren（https://github.com/ArtSabintsev/Siren）
//
//  App Store 构建在编译期通过 APPSTORE 编译条件区分（未来新增专用
//  Build Configuration 时注入 SWIFT_ACTIVE_COMPILATION_CONDITIONS）。
//

import Foundation

/// 应用分发渠道
enum DistributionChannel {
    case sparkleGitHub
    case appStore

    /// 当前构建的分发渠道。默认 GitHub 分发；App Store 构建定义 APPSTORE 条件。
    static var current: DistributionChannel {
        #if APPSTORE
        return .appStore
        #else
        return .sparkleGitHub
        #endif
    }
}

/// 渠道更新检查器抽象。每个分发渠道提供一个实现，调用方（设置页、启动流程）
/// 只面向该协议，不感知具体框架。
protocol UpdateChecking: AnyObject {
    /// 该渠道是否支持应用内更新（App Store 版本将由 Siren/系统更新接管）
    var isSupported: Bool { get }

    /// 手动检查更新（设置页按钮，有 UI 反馈）
    func checkForUpdates()

    /// 后台静默检查（启动时；由框架自己的调度策略决定是否提示）
    func checkForUpdatesInBackground()
}

/// 按当前分发渠道构造更新检查器
enum UpdateControllerFactory {

    static func makeUpdateChecker() -> UpdateChecking {
        switch DistributionChannel.current {
        case .sparkleGitHub:
            return SparkleUpdateController()
        case .appStore:
            return AppStoreUpdateController()
        }
    }
}

// MARK: - AppVersion

/// 应用版本号便捷读取
enum AppVersion {
    /// 营销版本（CFBundleShortVersionString，如 "2.3.1"）
    nonisolated static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// 构建号（CFBundleVersion）
    nonisolated static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}
