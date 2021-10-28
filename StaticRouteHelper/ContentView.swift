//
//  ContentView.swift
//  StaticRouteHelper
//
//  Created by Derek Jing on 2021/3/24.
//

import SwiftUI
import Foundation


struct ContentView: View {
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
    
    var scrollHelper = ContentScrollView()
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
            PassEnterView(password: $password, passLock: $passLock, suCheck: suCheck)
                .padding(10)
                .opacity(passLock ? 0:1)
                
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
            }

        }.onAppear {
            if password != "" {
                suCheck.checkPass(password: password)
                DispatchQueue.main.asyncAfter(deadline: .now()+0.3) {
                    if suCheck.truePass == true {
                        self.passLock = true
                    }
                }
            }
            proHelper.checkRoute()
        }
    }
}
    


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(password: .constant("jingdian"), likeCount: .constant(1), setCount: .constant(200))
    }
}

