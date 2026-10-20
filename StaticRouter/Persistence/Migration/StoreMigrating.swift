//
//  StoreMigrating.swift
//  StaticRouteHelper
//
//  一次性迁移器（旧存储 → 当前 SwiftData 规则库）的统一抽象。
//

import Foundation
import SwiftData

/// 一次性迁移器的统一契约。
///
/// 实现约定（数据安全红线，历史上曾因违反而丢过用户数据）：
/// 1. 必须幂等：以源文件存在性为准，重复调用无事发生；
/// 2. 源文件只允许通过 StoreLocation.archiveStore 改名归档，绝不删除，
///    出问题可人工回滚；
/// 3. 「读取失败」绝不能当作「数据为空」：读不出内容时中止迁移并保留源文件，
///    下次启动重试。
@available(macOS 14, *)
protocol StoreMigrating {
    /// 执行迁移。应在 ModelContainer 创建之后、视图加载之前调用。
    func migrateIfNeeded(into context: ModelContext)
}
