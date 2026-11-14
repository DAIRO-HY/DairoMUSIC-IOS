//
//  UserAvatar.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI

/**
 用户头像,没有头像时显示App图标
 */
struct UserAvatar: View {

    /// 头像地址
    private let logo: String?

    private let size: CGFloat

    init(_ logo: String?, size: CGFloat) {
        self.logo = logo
        self.size = size
    }

    var body: some View {
        ZStack{
            if let logo = self.logo, !logo.isEmpty{
                MusicImage(logo, placeholder: "person.fill")
            } else {
                Image("logo").resizable()
            }
        }
        .frame(width: self.size, height: self.size)
        .clipShape(Circle())
    }
}
