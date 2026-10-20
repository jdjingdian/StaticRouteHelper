//
//  ContextSave.swift
//  StaticRouteHelper
//
//  统一的上下文保存入口：失败记录日志并返回 false，绝不静默丢弃。
//  历史上所有保存点都是 try? save()，存储层出错时用户毫不知情，
//  重启后才发现规则"消失"。
//

import Foundation
import SwiftData
import CoreData

@available(macOS 14, *)
extension ModelContext {

    /// 保存 SwiftData 上下文。成功返回 true；失败记录日志并返回 false。
    @discardableResult
    func saveOrLog(operation: String) -> Bool {
        guard hasChanges else { return true }
        do {
            try save()
            return true
        } catch {
            AppLog.persistence.error("保存失败 [\(operation, privacy: .public)]：\(String(describing: error), privacy: .public)")
            return false
        }
    }
}

extension NSManagedObjectContext {

    /// 保存 Core Data 上下文。成功返回 true；失败记录日志并返回 false。
    @discardableResult
    func saveOrLog(operation: String) -> Bool {
        guard hasChanges else { return true }
        do {
            try save()
            return true
        } catch {
            AppLog.persistence.error("保存失败 [\(operation, privacy: .public)]：\(String(describing: error), privacy: .public)")
            return false
        }
    }
}
