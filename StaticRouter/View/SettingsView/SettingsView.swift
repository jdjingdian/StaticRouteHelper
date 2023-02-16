//
//  SettingsView.swift
//  Static Router
//
//  Created by 经典 on 14/1/2023.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    private let width: CGFloat = 540
    let router = RouterCoreConnector()
    let appcore = AppCoreConnector()
    var body: some View {
        TabView {
            GeneralSettingsView(router: router).tabItem {
                Label("General",systemImage: "gear")
            }
//            ContentViewDev(router: router).tabItem {
//                Label("DEBUG",systemImage: "exclamationmark.arrow.triangle.2.circlepath")
//            }
            AboutView(appcore: appcore).tabItem {
                Label("About",systemImage: "questionmark.circle")
            }
        }.frame(width: width)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

extension SettingsView {
//    func AdaptiveLabel() -> Label{
//        return Label("About",systemImage: "questionmark.folder")
//    }
}
