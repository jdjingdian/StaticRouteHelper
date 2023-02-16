//
//  PaddedDivider.swift
//  Static Router
//
//  Created by 经典 on 14/1/2023.
//

import Foundation
import SwiftUI

struct PaddedDivider: View {
    let padding: CGFloat?
    var body: some View {
        Divider().padding(.vertical,padding ?? 5)
    }
}

struct PaddedDivider_Previews: PreviewProvider {
    static var previews: some View {
        PaddedDivider(padding: nil)
    }
}
