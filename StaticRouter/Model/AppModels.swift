//
//  AppModels.swift
//  StaticRouteHelper
//
//  Created by Derek Jing on 2021/10/27.
//

import Foundation

struct FramePreference {
    let minWidth: CGFloat?
    let minHeight: CGFloat?
    let maxWidth: CGFloat?
    let maxHeight: CGFloat?
    let idealWidth: CGFloat?
    let idealHeight: CGFloat?

    init(
        minWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        idealWidth: CGFloat? = nil,
        idealHeight: CGFloat? = nil
    ) {
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.idealWidth = idealWidth
        self.idealHeight = idealHeight
    }
}
