//
//  AppModels.swift
//  StaticRouteHelper
//
//  Created by Derek Jing on 2021/10/27.
//

import Foundation

struct FramePreference {
    let minWidth: CGFloat?
    let minHeight: CGFloat?
    let maxWidth: CGFloat?
    let maxHeight: CGFloat?
    let idealWidth: CGFloat?
    let idealHeight: CGFloat?
    
    init(minWidth: CGFloat? = nil, minHeight: CGFloat? = nil, maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil, idealWidth: CGFloat? = nil, idealHeight: CGFloat? = nil){
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.idealWidth = idealWidth
        self.idealHeight = idealHeight
    }
}

struct netData:Hashable {
    var index:Int
    var gateway: String
    var destination: String
    var flags: String
    var interface: String
    var expire: String
}

enum netType {
    case destination
    case gateway
    case flags
    case interface
    case expire
}

struct routeData:Hashable,Codable {
    var network:String = "192.168.3.0"
    var mask:String = "255.255.255.0"
    var gateway:String = "192.168.4.1"
    var interface:String = ""
    var isOn:Bool = false
}
