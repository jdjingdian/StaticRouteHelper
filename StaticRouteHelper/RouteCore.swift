//
//  RouteCore.swift
//  StaticRouteHelper
//
//  Created by Derek Jing on 2022/4/9.
//

import Foundation

//struct RouteInfo {
//    var riNetwork:String
//    var riNetMask:String
//    var riIsGateway:Bool
//    var riGateface:String
//}

struct RouteCore {
    private(set) var routes: Array<RouteCoreInfo>
    
    
    mutating func RouteSwitch(index: Int){
        //传入Array值？
        
        
        if routes[index].rciIsEnable{
            print("Turn Off routes")
        }else{
            print("Open Route")
        }
    }
    
    mutating func AddRoute(network:String,mask:String,isGateway:Bool,gate:String){
        let size = routes.count
        let newRoute = RouteCoreInfo(riNetwork: network, riNetMask: mask, riIsGateway: isGateway, riGateface: gate, id: size)
        routes.append(newRoute)
    }
    
    struct RouteCoreInfo :Identifiable{
        var riNetwork:String
        var riNetMask:String
        var riIsGateway:Bool
        var riGateface:String
        var rciIsEnable:Bool = false
        var id: Int
        //可能要补充一个id作为identifiable
    }
}
