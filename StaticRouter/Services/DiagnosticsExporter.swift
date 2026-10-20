//
//  DiagnosticsExporter.swift
//  StaticRouteHelper
//
//  导出诊断日志：环境信息 + 持久化状态 + 路由表快照 + 应用/助手统一日志。
//  用于用户报障时一键收集，提高定位效率（应用侧日志已通过 AppLog 接入
//  os.Logger，可用 `log show` 回捞）。
//
//  隐私说明：导出内容包含路由规则的目标/网关 IP 与本机路由表——
//  这是排障所需的关键信息，由用户主动选择保存位置并自行决定是否分享。
//

import AppKit
import Foundation
import SwiftData
import os

enum DiagnosticsExporter {

    // MARK: - Public

    /// 弹出保存面板并异步导出。完成/失败通过回调提示。
    @MainActor
    static func exportViaSavePanel() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultFileName()
        panel.message = "诊断日志包含应用与助手日志、路由表快照和规则列表，分享前请自行确认内容。"

        guard panel.runModal() == .OK, let targetURL = panel.url else { return }

        Task {
            do {
                try await export(to: targetURL)
                showDoneAlert(url: targetURL)
            } catch {
                AppLog.persistence.error("诊断日志导出失败：\(String(describing: error), privacy: .public)")
                showFailureAlert(error)
            }
        }
    }

    /// 组装并写出诊断内容。
    static func export(to targetURL: URL) async throws {
        var sections: [String] = []
        sections.append(headerSection())
        sections.append(await persistenceSection())
        sections.append(systemRouteSection())
        sections.append(await unifiedLogSection())

        let content = sections.joined(separator: "\n\n")
        try content.write(to: targetURL, atomically: true, encoding: .utf8)
        AppLog.persistence.info("诊断日志已导出：\(targetURL.path, privacy: .public)")
    }

    static func defaultFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "staticrouter-diagnostics-\(formatter.string(from: Date())).txt"
    }

    // MARK: - Sections

    private static func headerSection() -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let model = ProcessInfo.processInfo.hostName
        return """
        ================ Static Router 诊断日志 ================
        生成时间：\(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .medium))
        应用版本：\(AppVersion.current) (build \(AppVersion.build))
        系统：\(osVersion)
        主机名：\(model)
        """
    }

    /// 持久化与规则状态（macOS 14+）
    @MainActor
    private static func persistenceSection() async -> String {
        guard #available(macOS 14, *) else {
            return "---- 持久化（macOS 12/13 Core Data 路径，本机不适用）----"
        }

        var lines: [String] = ["---- 持久化状态 ----"]
        let storeURL = StoreLocation.swiftDataStoreURL
        lines.append("规则库路径：\(storeURL.path)")
        let fm = FileManager.default
        for suffix in StoreLocation.fileTrioSuffixes {
            let file = URL(fileURLWithPath: storeURL.path + suffix)
            if let attrs = try? fm.attributesOfItem(atPath: file.path),
               let size = attrs[.size] as? Int {
                lines.append("  \(file.lastPathComponent)：\(size) 字节")
            } else {
                lines.append("  \(file.lastPathComponent)：不存在")
            }
        }

        do {
            let context = SwiftDataBackend.shared.container.mainContext
            let rules = try context.fetch(FetchDescriptor<RouteRule>())
            let groups = try context.fetch(FetchDescriptor<RouteGroup>())
            lines.append("规则数量：\(rules.count)（激活 \(rules.filter(\.isActive).count) 条）；分组数量：\(groups.count)")
            for rule in rules {
                let type = rule.gatewayType == .ipAddress ? "ip" : "iface"
                let groupNames = rule.groups.map(\.name).joined(separator: ",")
                lines.append("  [\(rule.isActive ? "激活" : "停用")] \(rule.network)/\(rule.prefixLength) via \(type):\(rule.gateway) 分组[\(groupNames)] createdAt=\(rule.createdAt)")
            }
        } catch {
            lines.append("读取规则失败：\(error)")
        }
        return lines.joined(separator: "\n")
    }

    private static func systemRouteSection() -> String {
        var lines: [String] = ["---- 系统路由表快照（IPv4）----"]
        for entry in SystemRouteReader.readRoutes() {
            lines.append("  \(entry.destination) via \(entry.gateway) [\(entry.flags)] if=\(entry.networkInterface)")
        }
        return lines.joined(separator: "\n")
    }

    /// 回捞最近 24 小时的应用与助手统一日志。
    private static func unifiedLogSection() async -> String {
        let predicate = "subsystem CONTAINS 'cn.magicdian.staticrouter' OR processImagePath CONTAINS 'cn.magicdian.staticrouter.helper'"
        let arguments = [
            "show", "--last", "24h", "--info", "--style", "compact",
            "--predicate", predicate,
        ]

        let output: String = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
                } catch {
                    continuation.resume(returning: "（log show 执行失败：\(error.localizedDescription)）")
                }
            }
        }

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmed.isEmpty ? "（最近 24 小时无应用/助手日志）" : trimmed
        return "---- 应用与助手日志（最近 24 小时）----\n\(body)"
    }

    // MARK: - Alerts

    @MainActor
    private static func showDoneAlert(url: URL) {
        let alert = NSAlert()
        alert.messageText = "诊断日志已导出"
        alert.informativeText = "文件已保存到：\(url.path)"
        alert.addButton(withTitle: "好")
        alert.addButton(withTitle: "在访达中显示")
        if alert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    @MainActor
    private static func showFailureAlert(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "导出失败"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
