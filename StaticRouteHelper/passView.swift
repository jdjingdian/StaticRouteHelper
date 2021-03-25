//
//  passView.swift
//  StaticRouteHelper
//
//  Created by Derek Jing on 2021/3/24.
//

import Foundation
import SwiftUI
import Foundation


struct PassView: View {
    @State var isToggleOn = false
    var body: some View {
        Text("Enter Root Password")
        .padding()
        VStack{
            Toggle(isOn: $isToggleOn){
                Text("Enter password for root")
            }.padding()
        }
        
        
    }
    
}

struct PassView_Previews: PreviewProvider {
    static var previews: some View {
        PassView()
    }
}
