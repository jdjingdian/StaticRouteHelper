//
//  AboutView.swift
//  Static Router
//
//  Created by 经典 on 14/1/2023.
//

import Foundation
import SwiftUI

struct AboutView:View {
    @ObservedObject var appcore: AppCoreConnector
    private let img_length:CGFloat = 128
    var body: some View {
        VStack(alignment: .leading) {
            HStack(){
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: img_length, height: img_length)
                VStack(alignment: .leading){
                    Text("Static Route Helper")
                        .font(.largeTitle.bold())
                    Text("Help you manage macOS network routes.")
                        .font(.title3)
                    PaddedDivider(padding: nil)
                    Text("GUI Version: \(appcore.GetMainVer())")
                        .font(.caption.italic())
                    Text("Helper Tool Version: \(appcore.GetHelperVer())")
                        .font(.caption.italic())
                }
                
            }
            PaddedDivider(padding: nil)
            HStack(){
                VStack(alignment: .leading){
                    Text("StaticRouteHelper is licensed under the GPLv3 license.")
                    Text("Copyright © 2021, [Derek Jing](https://github.com/jdjingdian)")
                }
                Spacer()
                Button{
                    visitHomepage()
                } label: {
                    HStack(){
                        Image(systemName: "house")
                        Text("Project Home Page")
                            .font(.footnote)
                    }
                }.buttonStyle(DefaultButtonStyle(type: .buttonNeutral(.thin)))
            }
        }.padding()
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView(appcore: AppCoreConnector())
    }
}

extension AboutView {
    private func visitHomepage() {
        guard let url: URL = URL(string: "https://github.com/jdjingdian/StaticRouteHelper") else {
            return
        }
        
        NSWorkspace.shared.open(url)
    }
}
