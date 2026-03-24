//
//  ButtonStyle.swift
//  Static Router
//
//  Created by 经典 on 15/1/2023.
//

import Foundation
import SwiftUI

enum RouterTheme {
    static let accent = Color(red: 0.16, green: 0.44, blue: 0.90)
    static let accentSoft = accent.opacity(0.12)
    static let success = Color(red: 0.14, green: 0.62, blue: 0.40)
    static let warning = Color(red: 0.91, green: 0.59, blue: 0.11)
    static let danger = Color(red: 0.84, green: 0.26, blue: 0.22)
    static let subtleFill = Color.primary.opacity(0.05)
    static let subtleBorder = Color.primary.opacity(0.12)
    static let strongerBorder = Color.primary.opacity(0.20)
}

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
        self._disable = disable
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
            .overlay(
                RoundedRectangle(cornerRadius: GetRadius())
                    .stroke(_disable.wrappedValue ? RouterTheme.subtleBorder : RouterTheme.strongerBorder, lineWidth: 0.5)
            )
            .opacity(_disable.wrappedValue ? 0.72 : 1.0)
            .animation(.easeInOut(duration: 0.18), value: configuration.isPressed)
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
                    return Color.primary
                case .buttonDestory(_):
                    return Color.white
                case .buttonNeutral(_):
                    return Color.primary
                }
            }else{
                return Color.primary
            }
        }else{
            return Color.primary.opacity(0.7)
        }
    }
    
    func GetBackgroundColor(_ isPressed: Bool) -> Color {
        if(!self._disable.wrappedValue){
            if(focus){
                switch type{
                case .buttonConfirm(_):
                    return isPressed ? RouterTheme.accent.opacity(0.82): RouterTheme.accent
                case .buttonCancel(_):
                    return isPressed ? RouterTheme.subtleFill.opacity(1.4): RouterTheme.subtleFill
                case .buttonDestory(_):
                    return isPressed ? RouterTheme.danger.opacity(0.82): RouterTheme.danger
                case .buttonNeutral(_):
                    return isPressed ? RouterTheme.subtleFill.opacity(1.4): RouterTheme.subtleFill
                }
            }else{
                return RouterTheme.subtleFill
            }
        }else{
            return RouterTheme.subtleFill
        }
    }
}
