//
//  AppCoreConnector.swift
//  Static Router
//
//  Created by 经典 on 14/1/2023.
//

import Foundation
import SwiftUI

class AppCoreConnector: ObservableObject {
    private var appcore = AppCore()
    
    //MARK: USER INTENT
    func GetMainVer() -> String {
        return appcore.GetMainBundleVersion()
    }
    
    func GetHelperVer() -> String {
        return appcore.GetHelperBundleVersion()
    }
}
