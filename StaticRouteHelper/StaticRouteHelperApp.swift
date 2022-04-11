//
//  StaticRouteHelperApp.swift
//  StaticRouteHelper
//
//  Created by Derek Jing on 2021/3/24.
//

import SwiftUI

@main
struct StaticRouteHelperApp: App {
    @AppStorage("password") var password = ""
    @AppStorage("likeCount") var likeCount:Int = 0
    @AppStorage("setCount") var setCount:Int = 0
    let netinfo = RouteInterpreter()
    var version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    var body: some Scene {
        WindowGroup {
            ContentView(netinfo: netinfo, password: $password,likeCount: $likeCount,setCount: $setCount, coreDM: CoreDataManager())
                .navigationTitle("Static Route Helper")
                .navigationSubtitle(version ?? "")
        }.windowToolbarStyle(UnifiedWindowToolbarStyle())
        WindowGroup("Donate") {
            BuyCoffeeSubview(runCount: $setCount, likeCount: $likeCount)
        }.handlesExternalEvents(matching: Set(arrayLiteral: "like"))
        WindowGroup("Help") {
            HelpView()
        }.handlesExternalEvents(matching: Set(arrayLiteral: "help"))
    }
}
