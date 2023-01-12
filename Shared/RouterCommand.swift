//
//  RouterCommand.swift
//  StaticRouteHelper
//
//  Created by 经典 on 11/1/2023.
//

import Foundation


struct RouterCommand : Encodable,Decodable {
    let commandType: RouterCommandType
    let commandArgs:[String]
    
    enum GatewayType {
        case ipaddr
        case interface
    }
    
    static func BuildPrintRouteCommand() -> RouterCommand {
        return RouterCommand(commandType: .netstat, commandArgs: ["-nr","-f","inet"])/// | sed '1,4d' // not working here
    }
    
    static func BuildManageRouteCommand(addToRoute: Bool,network: String, mask: String, gateway: String, gatewayType: GatewayType) -> RouterCommand{
        return RouterCommand(commandType: .route, commandArgs: self.BuildRouteArgs(addToRoute, network, mask, gateway, gatewayType))
    }
    static func BuildRouteArgs(_ addToRoute: Bool,_ network: String,_ mask: String,_ gateway: String,_ gatewayType: GatewayType) -> [String] {
        let gateway_para: String
        var args: [String] = []
        switch addToRoute {
        case true:
            args.append("add")
        case false:
            args.append("delete")
        }
        args.append("-net")
        args.append(network)
        args.append("-netmask")
        args.append(mask)
        switch gatewayType {
        case .interface:
            gateway_para = "-iface"
        case .ipaddr:
            gateway_para = "-gateway"
        }
        args.append(gateway_para)
        args.append(gateway)
        return args
    }
}

enum RouterCommandType: Codable, CaseIterable {
    case netstat
    case route
    
    var launchPath: String{
        switch self{
        case .netstat:
            return "/usr/sbin/netstat"
        case .route:
            return "/sbin/route"
        }
    }
}

struct RouterCommandReply: Codable {
    let terminationStatus: Int32
    let standardOutput: String?
    let standardError: String?
}

//DEBUG useless
enum RouterCommandError: Error, Codable {
    case authorizationFaild
    case authorizationNotRequested
}
