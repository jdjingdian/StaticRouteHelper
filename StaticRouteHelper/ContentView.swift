//
//  ContentView.swift
//  StaticRouteHelper
//
//  Created by Derek Jing on 2021/3/24.
//

import SwiftUI
import Foundation


struct ContentView: View {
    @State var toggle = false
    @State var input = "jingdian"
    @State var network = "192.168.2.0"
    @State var mask = "255.255.255.0"
    @State var gateway = "192.168.3.4"

    
    var body: some View {
        Text("Static Route Helper")
        .padding()
        VStack{
//            HStack{
//                Text("Network")
//                Text("Mask")
//                Text("Gateway")
//            }
            HStack{
                TextField("network:", text: $network)
                TextField("mask:", text: $mask)
                TextField("gateway:", text: $gateway)
                Toggle(isOn: $toggle){
                    Text("启用")
                }.onChange(of: toggle, perform: { value in
                    print(value)
                    if value == true{
                        let taskOne = Process()
                        taskOne.launchPath = "/bin/echo"
                        taskOne.arguments = [input]

                        let taskTwo = Process()
                        taskTwo.launchPath = "/usr/bin/sudo"
                        taskTwo.arguments = ["-S", "route","-n","add","-net",network,"-netmask",mask,gateway]
                        
//                        taskTwo.launchPath = "/sbin/route"
//                        taskTwo.arguments = ["-n","add","-net","192.168.2.0","-netmask","255.255.255.0","192.168.3.4"]
                        let pipeBetween:Pipe = Pipe()
                        taskOne.standardOutput = pipeBetween
                        taskTwo.standardInput = pipeBetween

                        let pipeToMe = Pipe()
                        taskTwo.standardOutput = pipeToMe
                        taskTwo.standardError = pipeToMe

                        taskOne.launch()
                        taskTwo.launch()
                        let data = pipeToMe.fileHandleForReading.readDataToEndOfFile()
                            let output : String = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as! String
                            print(output)
                    }else{
                        let taskOne = Process()
                        taskOne.launchPath = "/bin/echo"
                        taskOne.arguments = [input]

                        let taskTwo = Process()
                        taskTwo.launchPath = "/usr/bin/sudo"
                        taskTwo.arguments = ["-S", "/sbin/route","delete","-net",network,"-gateway",gateway]
                        let pipeBetween:Pipe = Pipe()
                        taskOne.standardOutput = pipeBetween
                        taskTwo.standardInput = pipeBetween

                        let pipeToMe = Pipe()
                        taskTwo.standardOutput = pipeToMe
                        taskTwo.standardError = pipeToMe

                        taskOne.launch()
                        taskTwo.launch()
                    }
                    
                })
                
            }
            
            SecureField("请输入ROOT密码", text: $input).onChange(of: input, perform: { value in
                print(value)
            })
        }
        
        
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
