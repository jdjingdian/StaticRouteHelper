//
//  PassEnterView.swift
//  StaticRouteHelper
//
//  Created by Derek Jing on 2021/10/27.
//

import Foundation
import SwiftUI

struct PassEnterView: View {
    @Binding var password: String
    @Binding var passLock: Bool
    @ObservedObject var suCheck: SuHelper
    var body: some View {
        HStack(){
            suCheck.truePass ? Image(systemName: "checkmark.circle.fill").foregroundColor(.green):Image(systemName: "x.circle.fill").foregroundColor(.red)
            SecureField("Root Password", text: $password)
                .onChange(of: password) { value in
                    print(value)
                }
                .frame(maxWidth:100)
                .disabled(passLock)
            Toggle(isOn:$passLock){
                Image(systemName: "person.fill.questionmark")
            }.onChange(of: passLock) { value in
                if value ==  true {
                    suCheck.checkPass(password: password)
                }
                DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
                    if suCheck.truePass == false {
                        
                        passLock = false
                        
                    }
                }
                
            }
        }
    }
}

