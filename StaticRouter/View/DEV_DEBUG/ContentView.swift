//
//  ContentView.swift
//  StaticRouteHelper
//
//  Created by Derek Jing on 2021/3/24.
//

import SwiftUI
import Foundation

struct ContentView: View {
    @ObservedObject var router:RouterCoreConnector
    @Binding var password:String
    @Binding var likeCount:Int
    @Binding var setCount:Int
    @State var toggle = false
    @State var network = ""
    @State var mask = ""
    @State var gateway = ""
    
    @State var manualData = routeData()
    @State var manualList:[routeData] = []
    
    @State var passLock:Bool = false
    @State var interface: String = ""
    @ObservedObject var suCheck = SuHelper()
    @ObservedObject var proHelper = ProcessHelper()
    
    @State var testALert: Bool = true;
    let coreDM:CoreDataManager
    var scrollHelper = ContentScrollView()
    private let installMessage:String = "Install Helper to modify system route"
    var body: some View {
        VStack{
            HStack{
                RouteEnterView(manualData: $manualData, manualList: $manualList)
                    .padding(10)
                    .opacity(passLock ? 1:0)
                Button {
                    if let url = URL(string: "static://help") { //replace myapp with your app's name
                        NSWorkspace.shared.open(url)
                    }
                    
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .resizable()
                        .foregroundColor(.yellow)
                        .frame(width: 15, height: 15, alignment: .center)
                        .scaledToFit()
                        
                }
                BuyCoffeeView(likeCount: $likeCount)
                    .onChange(of: manualList.count) { newValue in
                        coreDM.resetData()
                        coreDM.saveData(array: manualList)
                    }
            }.padding(10)
            scrollHelper.manualRouteView(manualArray: $manualList, frameSettings: FramePreference(maxWidth:.infinity,idealHeight: 300), proHelper: proHelper, password: $password,setCount: $setCount)
                .frame(maxWidth:.infinity)
                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.gray,lineWidth: 1))
                .padding(10)
                .opacity(passLock ? 1:0)
            scrollHelper.netStatView(netArray :$proHelper.netArray, frameSettings: FramePreference(maxWidth:.infinity,idealHeight: 300))
                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.gray,lineWidth: 1))
                .padding(10)
                .opacity(passLock ? 1:0)
            HStack(){
//            PassEnterView(password: $password, passLock: $passLock, suCheck: suCheck)
//                .padding(10)
//                .opacity(passLock ? 0:1)
                
                Button {
                    for line in self.manualList{
                        if line.gateway != "" {
                            let arg = ["-S", "/sbin/route","delete","-net",line.network,"-netmask",line.mask,"-gateway",line.gateway]
                            proHelper.manualRoute(isAdd: false, password: password, args: arg)
                        }else if line.interface != ""{
                            let arg = ["-S", "/sbin/route","delete","-net",line.network,"-netmask",line.mask,"-iface",line.interface]
                            proHelper.manualRoute(isAdd: false, password: password, args: arg)
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
                        NSApp.terminate(self)
                    }
                    
                } label: {
                    Text("Exit")
                }
                
                Button{
                    router.CheckInstallState()
                }label: {
                    Text("Check Install")
                }
            }

        }.onAppear {
            if password != "" {
                suCheck.checkPass(password: password)
                DispatchQueue.main.asyncAfter(deadline: .now()+0.3) {
                    if suCheck.truePass == true {
                        self.passLock = true
                    }
                }
                self.manualList = coreDM.getAllData()
            }
            proHelper.checkRoute()
        }.alert(isPresented: .constant(true)) {
            return Alert(title: Text("Privileged Helper Tool not installed!"),message: Text("The Static Route Helper need to be installed in order to modified system route."), primaryButton: .default(Text("Install")){
                print("user try install helper")
                router.InstallHelper(message: LocalizedStringKey(installMessage).toString()+"\n\n")
            }, secondaryButton: .default(Text("Cancel")){
                print("user cancel alert")
            })
        }
    }
}
    


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(router: RouterCoreConnector(), password: .constant("jingdian"), likeCount: .constant(1), setCount: .constant(200), coreDM: CoreDataManager())
    }
}

extension LocalizedStringKey {

    /**
     Return localized value of thisLocalizedStringKey
     */
    public func toString() -> String {
        //use reflection
        let mirror = Mirror(reflecting: self)
        
        //try to find 'key' attribute value
        let attributeLabelAndValue = mirror.children.first { (arg0) -> Bool in
            let (label, _) = arg0
            if(label == "key"){
                return true;
            }
            return false;
        }
        
        if(attributeLabelAndValue != nil) {
            //ask for localization of found key via NSLocalizedString
            return String.localizedStringWithFormat(NSLocalizedString(attributeLabelAndValue!.value as! String, comment: ""));
        }
        else {
            return "Swift LocalizedStringKey signature must have changed. @see Apple documentation."
        }
    }
}
