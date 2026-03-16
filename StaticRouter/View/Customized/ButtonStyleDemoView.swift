//
//  ButtonStyleDemoView.swift
//  Static Router
//
//  Created by 经典 on 16/1/2023.
//

import Foundation
import SwiftUI

struct ButtonStyleDemoView: View {
    @Environment(\.controlActiveState) var controlActiveState
    @State var isFocused: Bool = false
    var body: some View {
        VStack(){
            HStack(){
                Button {
                } label: {
                    Text("Cancel")
                }.buttonStyle(DefaultButtonStyle(.buttonCancel(.bold), $isFocused))
                
                Button {

                } label: {
                    Text("Cancel")
                }.buttonStyle(DefaultButtonStyle(.buttonCancel(.normal), $isFocused))
                
                Button {

                } label: {
                    Text("Cancel")
                }.buttonStyle(DefaultButtonStyle(.buttonCancel(.thin), $isFocused))
                Button {

                } label: {
                    Text("Cancel")
                }.buttonStyle(DefaultButtonStyle(.buttonCancel(.small), $isFocused))
            }
            HStack(){
                Button {
                } label: {
                    Text("Confirm")
                }.buttonStyle(DefaultButtonStyle(.buttonConfirm(.bold), $isFocused))
                
                Button {

                } label: {
                    Text("Confirm")
                }.buttonStyle(DefaultButtonStyle(.buttonConfirm(.normal), $isFocused))
                
                Button {

                } label: {
                    Text("Confirm")
                }.buttonStyle(DefaultButtonStyle(.buttonConfirm(.thin), $isFocused))
                Button {

                } label: {
                    Text("Confirm")
                }.buttonStyle(DefaultButtonStyle(.buttonConfirm(.small), $isFocused))
            }
            HStack(){
                Button {
                } label: {
                    Text("删除")
                }.buttonStyle(DefaultButtonStyle(.buttonDestory(.bold), $isFocused))
                
                Button {
                    
                } label: {
                    Text("删除")
                }.buttonStyle(DefaultButtonStyle(.buttonDestory(.normal), $isFocused))
                
                Button {
                    
                } label: {
                    Text("删除")
                }.buttonStyle(DefaultButtonStyle(.buttonDestory(.thin), $isFocused))
                
                Button {
                    
                } label: {
                    Text("删除")
                }.buttonStyle(DefaultButtonStyle(.buttonDestory(.small), $isFocused))
                
            }
        }.padding()
            .onChange(of: controlActiveState) { state in
                switch(state){
                case .key:
                    isFocused = true
                    break
                case .inactive:
                    isFocused = false
                    break
                case .active:
                    isFocused = true
                    break
                @unknown default:
                    isFocused = false
                    break
                }
                print("active change to: \(state)")
            }
    }
}


struct ButtonStyleDemoView_Previews: PreviewProvider {
    static var previews: some View {
        ButtonStyleDemoView()
    }
}
