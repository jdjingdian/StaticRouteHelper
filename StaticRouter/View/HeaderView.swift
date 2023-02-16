//
//  HeaderView.swift
//  Static Router
//
//  Created by 经典 on 13/1/2023.
//

import Foundation
import SwiftUI

struct HeaderView: View {
    @Binding var sectionType: HeaderSectionType
    var body: some View {
        Picker("Header Type",selection: $sectionType) {
            ForEach(HeaderSectionType.allCases) { headerSectionType in
                Text("\(headerSectionType.description)").tag(headerSectionType)
            }
        }.pickerStyle(.segmented)
            .labelsHidden()
            .padding()
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(HeaderSectionType.allCases) { headerType in
            HeaderView(sectionType: .constant(headerType))
        }
    }
}
