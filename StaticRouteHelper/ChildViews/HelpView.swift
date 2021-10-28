//
//  HelpView.swift
//  UDown Helper
//
//  Created by Derek Jing on 2021/10/25.
//

import Foundation
import SwiftUI

struct HelpView: View{
    var body:some View {
        NavigationView(){
            
            List{
                NavigationLink(destination: TutorialView()) {
                    HStack(){
                        Image(systemName: "person.fill.questionmark")
                            .resizable()
                            .foregroundColor(.black)
                            .frame(width: 15, height: 15, alignment: .center)
                            .scaledToFit()
                        Text("Tutorial")
                            .fontWeight(.bold)
                    }
                }
                
                NavigationLink(destination: ResetCoreDataView()){
                    HStack(){
                        Image(systemName: "gobackward")
                            .resizable()
                            .foregroundColor(.black)
                            .frame(width: 15, height: 15, alignment: .center)
                            .scaledToFit()
                        Text("Reset")
                            .fontWeight(.bold)
                    }
                    
                }
                
                NavigationLink(destination: ResetStateView()){
                    HStack(){
                        Image(systemName: "gobackward")
                            .resizable()
                            .foregroundColor(.black)
                            .frame(width: 15, height: 15, alignment: .center)
                            .scaledToFit()
                        Text("Reset")
                            .fontWeight(.bold)
                    }
                    
                }
            }
            
        }

    }
}



struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}

struct ResetStateView: View{
    var body: some View {
        VStack{
            Text("⚠️Tap the button to reset the app.⚠️")
                .fontWeight(.bold)
            Button {
                let domain = Bundle.main.bundleIdentifier!
                UserDefaults.standard.removePersistentDomain(forName: domain)
                UserDefaults.standard.synchronize()
                NSApp.terminate(self)
                
            } label: {
                
                HStack(){
                    Image(systemName: "gobackward")
                        .resizable()
                        .foregroundColor(.black)
                        .frame(width: 15, height: 15, alignment: .center)
                        .scaledToFit()
                    Text("Reset")
                        .fontWeight(.bold)
                }
            }
        }
    }
}

struct ResetCoreDataView:View{
    let coreDM:CoreDataManager = CoreDataManager()
    var body: some View{
        Button {
            coreDM.resetData()
            DispatchQueue.main.asyncAfter(deadline: .now()+0.5 ){
                NSApp.terminate(self)
            }
        } label: {
            Text("Reset Routing Database")
        }

    }
}

struct TutorialView:View{
    var body: some View{
        Text("匆忙施工中，请先看Github，以及自己摸索")
        
    }
}
