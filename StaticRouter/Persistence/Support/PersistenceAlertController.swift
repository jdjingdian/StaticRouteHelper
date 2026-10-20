//
//  PersistenceAlertController.swift
//  StaticRouteHelper
//
//  编辑场景的保存失败提示器：保存失败时除了写日志，还弹 alert 告知用户，
//  避免"以为保存了、重启才发现没保存"的体验。
//
//  通过 environmentObject 注入；后台场景（启动校准、状态同步等）直接用
//  ModelContext.saveOrLog 记日志即可，不打扰用户。
//

import SwiftUI
import SwiftData

/// 一次可呈现给用户的保存失败信息
struct PersistenceFailure: Identifiable {
    let id = UUID()
    let message: String
}

@MainActor
final class PersistenceAlertController: ObservableObject {

    @Published var currentFailure: PersistenceFailure?

    /// 供 .alert(isPresented:) 使用的绑定
    var isFailurePresented: Binding<Bool> {
        Binding(
            get: { [weak self] in self?.currentFailure != nil },
            set: { [weak self] presented in
                if !presented { self?.currentFailure = nil }
            }
        )
    }

    /// 保存上下文；失败记录日志，并在 userFacing 为 true 时设置弹窗内容。
    @available(macOS 14, *)
    @discardableResult
    func save(_ context: ModelContext, operation: String, userFacing: Bool = true) -> Bool {
        let success = context.saveOrLog(operation: operation)
        if !success && userFacing {
            currentFailure = PersistenceFailure(
                message: String(localized: "persistence.alert.save_failed.message")
            )
        }
        return success
    }
}

// MARK: - View helper

/// 在当前视图上挂载「保存失败」弹窗。编辑类 Sheet / 视图必须挂载，
/// 否则 userFacing 的失败只会出现在日志里。
extension View {

    func persistenceFailureAlert(_ controller: PersistenceAlertController) -> some View {
        alert(
            "persistence.alert.save_failed.title",
            isPresented: controller.isFailurePresented,
            presenting: controller.currentFailure
        ) { _ in
            Button(String(localized: "common.ok"), role: .cancel) {
                controller.currentFailure = nil
            }
        } message: { failure in
            Text(failure.message)
        }
    }
}
