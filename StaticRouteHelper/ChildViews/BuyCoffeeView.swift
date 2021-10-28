//
//  BuyCoffeeView.swift
//  UDown Helper
//
//  Created by Derek Jing on 2021/10/25.
//

import Foundation
import SwiftUI

struct BuyCoffeeView: View {
    @Binding var likeCount:Int
    var body: some View {
        if likeCount < 10{
            Button {
          
                    if let url = URL(string: "static://like") { //replace myapp with your app's name
                        NSWorkspace.shared.open(url)

                }
                
            } label: {
                Image(systemName: "hand.thumbsup.fill")
                    .resizable()
                    .foregroundColor(.orange)
                    .frame(width: 15, height: 15, alignment: .center)
                    .scaledToFit()
                    
            }
        }
        }
        
}


struct BuyCoffeeView_Previews:PreviewProvider {
    static var previews: some View{
        BuyCoffeeView(likeCount: .constant(10))
    }
}

struct BuyCoffeeSubview: View {
    @Binding var runCount: Int
    @Binding var likeCount:Int
    var body: some View {
        VStack(){
            Text("This tool has helped you set routing \(String(runCount)) times.")
                .fontWeight(.bold)
                .foregroundColor(Color("textColor"))
            Image("like")
                .onTapGesture {
                    likeCount += 1
                }
            Text("Use WeChat to scan the qrcode to buy me a coffee")
                .fontWeight(.bold)
                .foregroundColor(Color("textColor"))
            
            Text("Tap qrcode \(String(10-likeCount)) times to disable this page")
                .foregroundColor(Color("textColor").opacity(0.5))
                .fontWeight(.light)
                .padding(.all,20)
        }.padding(.all,20)
    }
}
struct BuyCoffeeSubview_Previews:PreviewProvider{
    static var previews: some View{
        BuyCoffeeSubview(runCount: .constant(10), likeCount: .constant(5))
    }
}
