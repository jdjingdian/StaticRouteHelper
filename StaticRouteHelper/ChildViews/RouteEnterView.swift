//
//  RouteEnterView.swift
//  StaticRouteHelper
//
//  Created by Derek Jing on 2021/10/28.
//

import Foundation
import SwiftUI

struct RouteEnterView: View {
    @ObservedObject var netinfo: RouteInterpreter
    @Binding var manualData: routeData
    @Binding var manualList: [routeData]
    @State var plusColor:Color = .blue
    var body: some View {
        HStack(){
            TextField("network:", text: $manualData.network)
                .background(Color("defaultBackground"))
                .cornerRadius(40)
            TextField("mask:", text: $manualData.mask)
                .background(Color("defaultBackground"))
                .cornerRadius(40)
            TextField("gateway:", text: $manualData.gateway)
                .background(manualData.interface != "" ? Color("buttonBackground"):Color("defaultBackground"))
                .disabled(manualData.interface != "")
                .cornerRadius(40)
            TextField("Interface", text: $manualData.interface)
                .background(manualData.gateway != "" ? Color("buttonBackground"):Color("defaultBackground"))
                .disabled(manualData.gateway != "")
                .cornerRadius(40)
            Image(systemName: "plus.circle.fill")
                .foregroundColor(plusColor)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray,lineWidth: 1))
                .onTapGesture {
                    plusColor = Color("highlight")
//
//                    var trueData = manualData
//                    var falseData = manualData
//                    trueData.isOn = true
//                    falseData.isOn = false
//
//                    if manualList.contains(trueData){
//                        print("数据已存在")
//                    }else if manualList.contains(falseData){
//                        print("数据已存在")
//                    }else{
//                        manualList.append(manualData)
//                    }
//
//
//                    print(manualList)
                    if manualData.gateway == ""{
                        netinfo.AddRoute(network: manualData.network, mask: manualData.mask, isGateway: false, gate: manualData.interface)
                    }else if manualData.interface == ""{
                        netinfo.AddRoute(network: manualData.network, mask: manualData.mask, isGateway: true, gate: manualData.gateway)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
                        plusColor = .blue
                    }
                }.allowsHitTesting(manualData.network != ""&&manualData.mask != ""&&(manualData.gateway != ""||manualData.interface != ""))
        }
    }
}
