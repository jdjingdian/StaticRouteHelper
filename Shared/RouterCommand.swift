//
//  RouterCommand.swift
//  StaticRouteHelper
//
//  Created by 经典 on 11/1/2023.
//

import Foundation

// MARK: - GatewayType

/// Describes how the gateway for a route is specified.
enum GatewayType: String, Codable, CaseIterable {
    /// The gateway is an IPv4 address (e.g. "192.168.1.1").
    case ipAddress
    /// The gateway is a network interface name (e.g. "en0").
    case interface
}

// MARK: - RouteWriteRequest

/// XPC message sent from the main app to the Helper to add or remove a route via PF_ROUTE socket.
struct RouteWriteRequest: Codable {
    let network: String
    let mask: String
    let gateway: String
    let gatewayType: GatewayType
    let add: Bool
}

// MARK: - RouteWriteReply

/// XPC reply returned by the Helper after a PF_ROUTE socket write attempt.
struct RouteWriteReply: Codable {
    let success: Bool
    let errorMessage: String?
}

// MARK: - RouterCommand (legacy — netstat path only)

struct RouterCommand: Encodable, Decodable {
    let commandType: RouterCommandType
    let commandArgs: [String]

    @available(*, deprecated, message: "Use SystemRouteReader.readRoutes() instead. BuildPrintRouteCommand() will be removed in v1.3.0.")
    static func BuildPrintRouteCommand() -> RouterCommand {
        return RouterCommand(commandType: .netstat, commandArgs: ["-nr", "-f", "inet"])
    }
}

enum RouterCommandType: Codable, CaseIterable {
    case netstat

    var launchPath: String {
        switch self {
        case .netstat:
            return "/usr/sbin/netstat"
        }
    }
}

// MARK: - RouterCommandError (DEBUG)

//DEBUG useless
enum RouterCommandError: Error, Codable {
    case authorizationFaild
    case authorizationNotRequested
}
