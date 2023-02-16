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
    let router = RouterCoreConnector()
    let profileSwitcher = LocationProfileSwitcher()
    let app_version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    var body: some Scene {
        WindowGroup {
            MainWindow(profileSwitcher: profileSwitcher)
                .navigationTitle("Static Route Helper")
                .navigationSubtitle(app_version ?? "").onReceive(NotificationCenter.default.publisher(for: NSApplication.willUpdateNotification)) { _ in
                    hideZoomButton()
                }
        }.commands {
            MenuBarCommand()
        }
        Settings {
            SettingsView()
        }
    }
    
    func hideZoomButton() {

        for window in NSApplication.shared.windows {

            guard let button: NSButton = window.standardWindowButton(NSWindow.ButtonType.zoomButton) else {
                continue
            }

            button.isEnabled = false
        }
    }
}



//        .windowToolbarStyle(UnifiedWindowToolbarStyle())
//        WindowGroup("Donate") {
//            BuyCoffeeSubview(runCount: $setCount, likeCount: $likeCount)
//        }.handlesExternalEvents(matching: Set(arrayLiteral: "like"))
//        WindowGroup("Help") {
//            HelpView()
//        }.handlesExternalEvents(matching: Set(arrayLiteral: "help"))
