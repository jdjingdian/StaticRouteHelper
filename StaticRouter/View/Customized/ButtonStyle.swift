//
//  ButtonStyle.swift
//  Static Router
//
//  Created by 经典 on 15/1/2023.
//

import Foundation
import SwiftUI

struct DefaultButtonStyle: ButtonStyle {
    private var type: DefaultButtonType
    @Binding var focus: Bool
    @Binding var disable: Bool
    init(_ buttonType: DefaultButtonType, _ focus: Binding<Bool>){
        type = buttonType
        self.type = buttonType
        self._focus = focus
        self._disable = Binding<Bool>.constant(false)
    }
    
    init(_ buttonType: DefaultButtonType, _ focus: Binding<Bool>, _ disable: Binding<Bool>){
        type = buttonType
        self.type = buttonType
        self._focus = focus
        self._disable = Binding<Bool>.constant(false)
    }
    
    init(_ buttonType: DefaultButtonType, disable: Binding<Bool>){
        type = buttonType
        self.type = buttonType
        self._focus = Binding<Bool>.constant(true)
        self._disable = disable
    }
    
    init(type: DefaultButtonType){
        self.type = type
        self._focus = Binding<Bool>.constant(true)
        self._disable = Binding<Bool>.constant(false)
    }
    
    
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GetFont())
            .padding(GetPaddingEdge())
            .foregroundColor(GetForegroundColor())
            .background(GetBackgroundColor(configuration.isPressed))
            .cornerRadius(GetRadius())
            .overlay(RoundedRectangle(cornerRadius: GetRadius()).stroke(lineWidth: 0.5).opacity(0.2))
    }
    
    enum DefaultButtonType{
        case buttonConfirm(_ style: ButtonStyle)
        case buttonCancel(_ style: ButtonStyle)
        case buttonDestory(_ style: ButtonStyle)
        case buttonNeutral(_ style: ButtonStyle)
        
        var style: ButtonStyle {
            switch self {
            case .buttonConfirm(let style):
                return style
            case .buttonCancel(let style):
                return style
            case .buttonDestory(let style):
                return style
            case .buttonNeutral(let style):
                return style
            }
        }
    }
    
    enum ButtonStyle{
        case normal
        case bold
        case thin
        case small
    }
}

extension DefaultButtonStyle {
    //MARK: Size and fonts
    func GetPaddingEdge() -> EdgeInsets {
        let vertical: CGFloat
        let horizon: CGFloat
        switch self.type.style {
        case .bold:
            vertical = 5
            horizon = 17
            break
        case .normal:
            vertical = 4
            horizon = 9
            break
        case .thin:
            vertical = 3
            horizon = 6
        case .small:
            vertical = 3
            horizon = 4
            break
        }
        
        return EdgeInsets(top: vertical, leading: horizon, bottom: vertical, trailing: horizon)
    }
    
    func GetRadius() -> CGFloat {
        switch self.type.style {
        case .bold:
            return 7
        case .normal:
            return 6
        case .thin:
            return 5
        case .small:
            return 4
        
        }
    }
    
    func GetFont() -> Font {
        switch self.type.style {
        case .bold:
            return Font.headline.bold()
        case .normal:
            return Font.body.bold()
        case .thin:
            return Font.body
        case .small:
            return Font.footnote.monospacedDigit()
        }
    }
}

extension DefaultButtonStyle {
    //MARK: Foreground and background colors
    func GetForegroundColor() -> Color {
        if(!self._disable.wrappedValue){
            if(focus){
                switch type{
                case .buttonConfirm(_):
                    return Color.white
                case .buttonCancel(_):
                    return Color.black
                case .buttonDestory(_):
                    return Color.white
                case .buttonNeutral(_):
                    return Color.black
                }
            }else{
                return Color.primary
            }
        }else{
            return Color.primary.opacity(0.5)
        }
    }
    
    func GetBackgroundColor(_ isPressed: Bool) -> Color {
        if(!self._disable.wrappedValue){
            if(focus){
                switch type{
                case .buttonConfirm(_):
                    return isPressed ? Color.blue.opacity(0.7): Color.accentColor
                case .buttonCancel(_):
                    return isPressed ? Color.secondary.opacity(0.2): Color.white.opacity(0.6)
                case .buttonDestory(_):
                    return isPressed ? Color.red.opacity(0.7): Color.red
                case .buttonNeutral(_):
                    return isPressed ? Color.secondary.opacity(0.2): Color.white.opacity(0.6)
                }
            }else{
                return Color.white
            }
        }else{
            return Color.secondary.opacity(0.5)
        }
        
        
        
    }
}
