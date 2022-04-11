//
//  RouteInterpreter.swift
//  StaticRouteHelper
//
//  Created by Derek Jing on 2022/4/9.
//

import Foundation
import SwiftUI


class RouteInterpreter: ObservableObject {

    @Published private var netcore = RouteCore(routes: []) //创建一个空的Array?
    var routes: Array<RouteCore.RouteCoreInfo> {
        netcore.routes
    }
    
    //MARK: User Intend(s)
    func AddRoute(network:String,mask:String,isGateway:Bool,gate:String){
        netcore.AddRoute(network: network, mask: mask, isGateway: isGateway, gate: gate)
        print("MVVM add route")
        print(netcore)
    }
}
