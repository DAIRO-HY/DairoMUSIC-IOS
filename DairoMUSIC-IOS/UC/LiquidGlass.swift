//
//  LiquidGlass.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI

extension View {

    /// 液态玻璃背景,iOS 26以下系统使用毛玻璃
    /// - Parameter shape 背景形状
    /// - Parameter interactive 按下时是否有反馈
    @ViewBuilder
    func liquidGlassBackground<S: Shape>(in shape: S, interactive: Bool = false) -> some View{
        if #available(iOS 26.0, *){
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
                .contentShape(shape)
        } else {
            self.background(.regularMaterial, in: shape)
                .contentShape(shape)
        }
    }

    /// 带颜色的液态玻璃背景,iOS 26以下系统使用纯色
    /// - Parameter color 颜色
    /// - Parameter shape 背景形状
    @ViewBuilder
    func liquidGlassBackground<S: Shape>(_ color: Color, in shape: S) -> some View{
        if #available(iOS 26.0, *){
            self.glassEffect(.regular.tint(color).interactive(), in: shape)
                .contentShape(shape)
        } else {
            self.background(color, in: shape)
                .contentShape(shape)
        }
    }

    /// 浮在列表上面的顶部栏,iOS 26的列表内容滚动到顶部栏和状态栏后面时会自动渐隐
    @ViewBuilder
    func scrollTopBar<Content: View>(@ViewBuilder content: () -> Content) -> some View{
        if #available(iOS 26.0, *){
            self.safeAreaBar(edge: .top, spacing: 0, content: content)
        } else {
            self.safeAreaInset(edge: .top, spacing: 0, content: content)
        }
    }
}
