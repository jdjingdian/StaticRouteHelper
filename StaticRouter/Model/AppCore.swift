//
//  AppCore.swift
//  Static Router
//
//  Created by 经典 on 14/1/2023.
//

import Foundation

struct AppCore {
    private let sharedConstants:SharedConstant
    init(){
        do{
            sharedConstants = try SharedConstant()
        }catch{
            fatalError("""
            One or more property list configuration issues exist. Please check the PropertyListModifier.swift script \
            is run as part of the build process for both the app and helper tool targets. This script will \
            automatically create all of the necessary configurations.
            Issue: \(error)
            """)
        }
    }
    
    func GetMainBundleVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "null"
    }
    
    func GetHelperBundleVersion() -> String {
        return sharedConstants.helperToolVersion.rawValue
    }
}


