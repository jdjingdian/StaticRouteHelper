//
//  HeaderSectionType.swift
//  Static Router
//
//  Created by 经典 on 13/1/2023.
//

import Foundation

enum HeaderSectionType: String, CaseIterable, Identifiable {
    case management = "Manage Routes"
    case showroute = "System Routes"
    
    var id: String {
        rawValue
    }
    
    var description: String {
        rawValue
    }
    
}
