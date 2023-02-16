//
//  LocationProfileManageView.swift
//  Static Router
//
//  Created by 经典 on 15/1/2023.
//

import Foundation
import SwiftUI

struct LocationProfileManageView: View {
    @Environment(\.controlActiveState) var controlActiveState
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    ///Environment ↑
    private let width:CGFloat = 240
    private let height:CGFloat = 200
    private var defaultProfile: LocationProfiles.LocationProfile
    @ObservedObject var profileSwitcher: LocationProfileSwitcher
    @State var selection:LocationProfiles.LocationProfile? = nil
    @State var text_dev:String = ""
    @State var edit_mode:Bool = false
    @State var last_selection:LocationProfiles.LocationProfile? = nil
    
    
    init(switcher: LocationProfileSwitcher){
        self.profileSwitcher = switcher
        self.defaultProfile = switcher.GetDefaultProfile()
    }
    
    //MARK: 选中的时候再点击一次，就进入编辑模式
    var body: some View {
        VStack {
            VStack(){
                List(profileSwitcher.location_profiles, id:\.self,selection: $selection ){ profile in
                    if(profile.id != 1){
                        HStack(){
                            if(edit_mode && profile == last_selection){
                                TextField(profile.configName, text: $text_dev) {
                                    print("OnCommit")
                                    edit_mode = false
                                }.labelsHidden()
                            }
                            else{
                                Text(profile.configName).onTapGesture {
                                    edit_mode = false
                                    print("Tap")
                                    selection = profile
                                    if(selection == last_selection){
                                        print("retap last, enter edit")
                                        selection = nil
                                        edit_mode = true
                                    }
                                    last_selection = profile
                                
                                }
                            }
                            Spacer()
                        } .background(Divider().offset(y: 4.0), alignment: .bottom)
                    }
                }
                HStack(spacing: 0){
                    Button{
                        profileSwitcher.CreateNewProfile()
                    }label: {
                        Image(systemName: "plus")
                    }
                    
                    Button{
                        print("selection: \(selection)")
//                        profileSwitcher.DeleteProfile(selection ?? 2)
                        profileSwitcher.DeleteProfile(selection?.id ?? nil)
                        selection = profileSwitcher.GetDefaultProfile()
                    }label: {
                        Image(systemName: "minus")
                    }
                    .disabled(selection == profileSwitcher.GetDefaultProfile())
                    
                    Button{
                        
                    }label: {
                        Image(systemName: "gear")
                    }
                    Spacer()
                }.padding(5)
            }
            
            .border(Color.gray, width: 0.3)
            
            
            
            HStack(){
                Spacer()
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("完成")
                }.buttonStyle(DefaultButtonStyle(.buttonConfirm(.bold),Binding<Bool>(
                    get: {
                        return controlActiveState == .key
                    }, set: {_ in
                    }
                )))
            }
            
        }.frame(width: width,height: height)
            .padding()
            .onAppear(
                //load default?
                
            )
    }
}


struct LocationProfileManageView_Previews: PreviewProvider {
    static var previews: some View {
        LocationProfileManageView(switcher: LocationProfileSwitcher())
    }
}
