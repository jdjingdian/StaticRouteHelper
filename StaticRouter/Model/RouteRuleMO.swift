//
//  RouteRuleMO.swift
//  StaticRouteHelper
//
//  NSManagedObject subclass for the Legacy Core Data persistence stack (macOS 12–13)
//

import Foundation
import CoreData

/// Core Data managed object representing a static route rule on macOS 12–13.
/// Mirrors the fields of the SwiftData `RouteRule` @Model class, excluding group relationships.
@objc(RouteRuleMO)
final class RouteRuleMO: NSManagedObject {

    @NSManaged var id: UUID
    /// Target network address (e.g. "192.168.4.0")
    @NSManaged var network: String
    /// CIDR prefix length (e.g. 24)
    @NSManaged var prefixLength: Int16
    /// "ipAddress" or "interface"
    @NSManaged var gatewayType: String
    /// Gateway IP or interface name
    @NSManaged var gateway: String
    /// Whether the route is currently active in the system routing table
    @NSManaged var isActive: Bool
    /// Optional user note
    @NSManaged var note: String?
    @NSManaged var createdAt: Date

    // MARK: - Convenience Init

    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
        network: String,
        prefixLength: Int16,
        gatewayType: String,
        gateway: String,
        isActive: Bool = false,
        note: String? = nil
    ) -> RouteRuleMO {
        let mo = RouteRuleMO(context: context)
        mo.id = UUID()
        mo.network = network
        mo.prefixLength = prefixLength
        mo.gatewayType = gatewayType
        mo.gateway = gateway
        mo.isActive = isActive
        mo.note = note
        mo.createdAt = Date()
        return mo
    }

    // MARK: - Computed Helpers

    /// CIDR notation string, e.g. "192.168.4.0/24"
    var cidrNotation: String { "\(network)/\(prefixLength)" }

    /// Subnet mask string derived from prefix length, e.g. 24 → "255.255.255.0"
    var subnetMask: String {
        let pl = Int(prefixLength)
        guard pl >= 0, pl <= 32 else { return "0.0.0.0" }
        let mask: UInt32 = pl == 0 ? 0 : (~UInt32(0) << (32 - pl))
        return "\((mask>>24)&0xFF).\((mask>>16)&0xFF).\((mask>>8)&0xFF).\(mask&0xFF)"
    }
}

// MARK: - Identifiable

extension RouteRuleMO: Identifiable {
    // `id` is already declared as @NSManaged var id: UUID above,
    // so Identifiable is satisfied automatically.
}
