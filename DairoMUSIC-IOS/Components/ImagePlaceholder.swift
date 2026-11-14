//
//  ImagePlaceholder.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI

/**
 图片还没有显示出来时的占位图,加载中、加载失败、服务器还没有生成缩略图时使用
 图标大小跟随占位区域,大格子和小格子看起来比例一样
 */
struct ImagePlaceholder: View {

    /// SF Symbols图标名
    private let icon: String

    init(_ icon: String) {
        self.icon = icon
    }

    var body: some View {
        GeometryReader{ geometry in
            Image(systemName: self.icon)
                .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.3))
                .foregroundColor(Color(uiColor: .tertiaryLabel))
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

#Preview {
    ImagePlaceholder("photo").frame(width: 130, height: 130)
}
