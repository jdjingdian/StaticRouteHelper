//
//  MainWindow.swift
//  Static Router
//
//  Created by 经典 on 12/1/2023.
//

import Foundation
import SwiftUI

struct MainWindow: View {
    let height:CGFloat = 720
    let width: CGFloat = 480
    @ObservedObject var profileSwitcher: LocationProfileSwitcher
    @State var selectedProfile = ""
    @State private var showProfileManager: Bool = false
    @State private var lastSelectedProfile = ""
    @State private var headerSection: HeaderSectionType = .management
    @State private var locationSelection: HeaderSectionType = .management
    @State private var text_dev: String = ""
    var body: some View {
        VStack(){
//            ButtonStyleDemoView()
            HeaderView(sectionType: $headerSection)
            Divider()
            VStack(){
                Picker(selection: self.$selectedProfile,label: Text("Location").font(.title3.bold())) {
                    ForEach(self.profileSwitcher.location_profiles){ profile in
                        if(profile.id != 1){Text(profile.configName).tag(profile.configName)}
                    }
                    Divider()
                    Text(profileSwitcher.location_profiles[1].configName).tag("profile.configName")

                    
                }.pickerStyle(.menu)
                    .frame(width: 200)
                    .onChange(of: $selectedProfile.wrappedValue) { identify in
                        if(identify == "profile.configName"){
                            print("Setting")
                            selectedProfile = lastSelectedProfile
                            showProfileManager = true
                        }
                        ///END
                        lastSelectedProfile = selectedProfile
                    }
            }.sheet(isPresented: $showProfileManager){
                LocationProfileManageView(switcher: profileSwitcher)
            }
            List{
                Text("DEBUG")
                Label("Manage Routes",systemImage: "hand.tap")
                Label("System Routes", systemImage: "network")
            }
            
//            Spacer()
            Divider()
            
        }.frame(width: width,height: height)
    }
}
struct MainWindow_Previews: PreviewProvider {
    static var previews: some View{
        MainWindow(profileSwitcher: LocationProfileSwitcher())
    }
}
