//
//  ScrollView.swift
//  StaticRouteHelper
//
//  Created by Derek Jing on 2021/10/27.
//

import Foundation
import SwiftUI


struct ContentScrollView{
    func netStatView(netArray:Binding<[netData]>, frameSettings:FramePreference) -> some View{
        ScrollViewReader { proxy in
            ScrollView(){
                VStack(){
                    HStack(){
                        NetTypeListView(dest:true, width: 160,title:"Destination",imgName:"airplane.arrival",netArray: netArray)
                        NetTypeListView(gate:true, width: 160, title:"Gateway",imgName:"airplane.departure",netArray: netArray)
                        NetTypeListView(flags:true, width: 80,title:"Flags",imgName:"flag.fill", netArray: netArray)
                        NetTypeListView(interface:true, width: 80, title:"Interface",imgName:"cable.connector",netArray: netArray)
                        NetTypeListView(expire:true, width: 80, title:"Expire",imgName:"clock.arrow.circlepath",netArray: netArray)
                    }
                    
                }.padding(10)
            }.frame(minWidth: frameSettings.minWidth, idealWidth: frameSettings.idealWidth, maxWidth: frameSettings.maxWidth, minHeight: frameSettings.minHeight, idealHeight: frameSettings.idealHeight, maxHeight: frameSettings.maxHeight,alignment: .leading)
        }.clipped()
    }
    
    func manualRouteView(manualArray: Binding<[routeData]>,frameSettings:FramePreference,proHelper:ProcessHelper,password:Binding<String>,setCount:Binding<Int>) -> some View{
        ScrollViewReader{ proxy in
            ScrollView(){
                VStack(){
                    HStack(alignment: .center, spacing: 80){
                        VStack(){
                            Text("Network")
                            ForEach(manualArray, id:\.self) { line in
                                Text(line.network.wrappedValue)
                                    .frame(width: 100, height: 30, alignment: .leading)
                            }
                        }
                        VStack(){
                            HStack(){
                                Text("Mask")
                                Text("Via")
                                    .foregroundColor(.blue)
                            }
                            
                            ForEach(manualArray, id:\.self) { line in
                                Text(line.mask.wrappedValue)
                                    .frame(width: 100, height: 30, alignment: .leading)
                            }
                        }
                        VStack(alignment:.leading){
                            Text("Gateway/Interface")
                            ForEach(manualArray, id:\.self) { line in
                                
                                HStack(alignment:.center){
                                    if line.gateway.wrappedValue != ""{
                                        Text(line.gateway.wrappedValue)
                                            .frame(width: 100, height: 30, alignment: .leading)
                                    }else if line.interface.wrappedValue != ""{
                                        Text(line.interface.wrappedValue)
                                            .frame(width: 100, height: 30, alignment: .leading)
                                    }
                                    Button {
                                        var arg:[String] = []
                                        print("Toggle状态\(line.isOn.wrappedValue)")
                                        line.isOn.wrappedValue.toggle()
                                        
                                        if line.isOn.wrappedValue == true {
                                            if line.gateway.wrappedValue != "" {
                                                arg = ["-S", "/sbin/route","-n","add","-net",line.network.wrappedValue,"-netmask",line.mask.wrappedValue,line.gateway.wrappedValue]
                                            }else if line.interface.wrappedValue != "" {
                                                arg = ["-S", "/sbin/route","-n","add","-net",line.network.wrappedValue,"-netmask",line.mask.wrappedValue,"-iface",line.interface.wrappedValue]
                                            }
                                            proHelper.manualRoute(isAdd: true, password: password.wrappedValue, args: arg)
                                        }else{
                                            if line.gateway.wrappedValue != "" {
                                                arg = ["-S", "/sbin/route","delete","-net",line.network.wrappedValue,"-netmask",line.mask.wrappedValue,line.gateway.wrappedValue]
                                            }else if line.interface.wrappedValue != "" {
                                                arg = ["-S", "/sbin/route","delete","-net",line.network.wrappedValue,"-netmask",line.mask.wrappedValue,"-iface",line.interface.wrappedValue]
                                            }
                                            proHelper.manualRoute(isAdd: true, password: password.wrappedValue, args: arg)
                                        }
                                        
                                        
                                        
                                        setCount.wrappedValue += 1
                                        proHelper.checkRoute()
                                        
                                    } label: {
                                        if line.isOn.wrappedValue == true {
                                            Image(systemName: "antenna.radiowaves.left.and.right")
                                                .resizable()
                                                .frame(width: 15, height: 15, alignment: .center)
                                                .scaledToFit()
                                                .foregroundColor(.green)
                                        }else{
                                            Image(systemName:"antenna.radiowaves.left.and.right.slash")
                                                .resizable()
                                                .frame(width: 15, height: 15, alignment: .center)
                                                .scaledToFit()
                                        }
                                    }.buttonStyle(.borderless)
                                    
                                    Image(systemName: "minus.circle.fill")
                                        .resizable()
                                        .frame(width: 15, height: 15, alignment: .center)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray,lineWidth: 1))
                                        .foregroundColor(.red.opacity(0.8))
                                        .onTapGesture {
                                            manualArray.wrappedValue.removeAll(where: {$0 == line.wrappedValue})
                                        }
                                        .opacity(line.isOn.wrappedValue ? 0:1)
                                        .allowsHitTesting(!line.isOn.wrappedValue)
                                        .scaledToFit()
                                }
                            }
                        }.frame(idealWidth:160)         
                    }
                }
            }
            
        }
    }
    
}

struct ContentScrollView_Previews: PreviewProvider {
    static var previews: some View {
        ContentScrollView().netStatView(netArray: .constant([netData]()), frameSettings: FramePreference())
        ContentScrollView().manualRouteView(manualArray: .constant([routeData]()), frameSettings: FramePreference(), proHelper: ProcessHelper(), password: .constant("jingdian"), setCount: .constant(200))
    }
}


struct NetTypeListView: View {
    var dest:Bool? = false
    var gate:Bool? = false
    var flags:Bool? = false
    var interface:Bool? = false
    var expire:Bool? = false
    var width:CGFloat
    var title: String
    var imgName:String
    @Binding var netArray:[netData]
    var body: some View {
        VStack(alignment:.leading,spacing:5){
            HStack(spacing:3){
                Image(systemName: imgName)
                Text(title)
            }.frame(width: width,alignment: .leading)
            
            ForEach(netArray,id:\.self){ line in
                VStack() {
                    if(self.dest == true){
                        Text(line.destination)
                            .frame(width: width,alignment: .leading)
                    }else if(self.gate == true){
                        Text(line.gateway)
                            .frame(width: width,alignment: .leading)
                    }else if(self.flags == true){
                        Text(line.flags)
                            .frame(width: width,alignment: .leading)
                    }else if(self.interface == true){
                        Text(line.interface)
                            .frame(width: width,alignment: .leading)
                    }else if(self.expire == true){
                        Text(line.expire)
                            .frame(width: width,alignment: .leading)
                    }
                }
            }
        }
    }
}
