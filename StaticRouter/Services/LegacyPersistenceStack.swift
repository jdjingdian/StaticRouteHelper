//
//  LegacyPersistenceStack.swift
//  StaticRouteHelper
//
//  Core Data persistence stack for macOS 12–13.
//  Wraps NSPersistentContainer and exposes the view context for SwiftUI.
//

import Foundation
import CoreData

/// Core Data persistence stack used on macOS 12–13 (legacy path).
/// On macOS 14+ the app uses SwiftData instead.
final class LegacyPersistenceStack: ObservableObject {

    static let modelName = "StaticRouteLegacy"

    // MARK: - Persistent Container

    let container: NSPersistentContainer

    /// The main thread managed object context for SwiftUI use.
    var viewContext: NSManagedObjectContext { container.viewContext }

    // MARK: - Init

    init() {
        guard let modelURL = Bundle.main.url(forResource: Self.modelName, withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("[LegacyPersistenceStack] Cannot find Core Data model '\(Self.modelName).momd' in bundle.")
        }
        container = NSPersistentContainer(name: Self.modelName, managedObjectModel: model)
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("[LegacyPersistenceStack] Failed to load persistent stores: \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Save

    /// Saves the view context if there are any changes.
    func save() {
        let context = viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("[LegacyPersistenceStack] Save failed: \(error)")
        }
    }

    // MARK: - Migration helpers

    /// Returns all RouteRuleMO records as plain dictionaries suitable for
    /// reconstructing in a SwiftData context on macOS 14+.
    func fetchAllRouteData() -> [[String: Any]] {
        let fetchRequest = NSFetchRequest<RouteRuleMO>(entityName: "RouteRuleMO")
        guard let results = try? viewContext.fetch(fetchRequest) else { return [] }
        return results.map { mo in
            [
                "id": mo.id,
                "network": mo.network,
                "prefixLength": Int(mo.prefixLength),
                "gatewayType": mo.gatewayType,
                "gateway": mo.gateway,
                "isActive": mo.isActive,
                "note": mo.note as Any,
                "createdAt": mo.createdAt
            ]
        }
    }

    /// Whether the legacy Core Data store file exists on disk (used to detect upgrade scenario).
    var storeFileExists: Bool {
        guard let storeURL = container.persistentStoreCoordinator.persistentStores.first?.url else {
            return false
        }
        return FileManager.default.fileExists(atPath: storeURL.path)
    }

    /// Deletes the Core Data store files (.sqlite, -wal, -shm).
    func deleteLegacyStoreFiles() {
        guard let storeURL = container.persistentStoreCoordinator.persistentStores.first?.url else { return }
        // Detach the store first
        if let store = container.persistentStoreCoordinator.persistentStores.first {
            try? container.persistentStoreCoordinator.remove(store)
        }
        for ext in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: storeURL.path + ext)
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
