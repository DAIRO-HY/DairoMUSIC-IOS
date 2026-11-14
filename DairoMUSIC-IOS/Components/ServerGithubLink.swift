//
//  ServerGithubLink.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/11.
//

import SwiftUI

/// 服务器端的GitHub项目地址,点击用浏览器打开,固定显示在页面最底部(安全区域里面)
/// 键盘弹出时隐藏,不然会被键盘顶上去盖住页面上的按钮
struct ServerGithubLink: View {

    /// 地址上面的说明
    private let title: String

    /// 键盘是否正在显示
    @State private var isKeyboardShown = false

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        VStack(spacing: 6){
            if !self.isKeyboardShown{
                self.content
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)){ _ in
            self.isKeyboardShown = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)){ _ in
            self.isKeyboardShown = false
        }
    }

    /// 说明和地址
    private var content: some View {
        VStack(spacing: 6){
            Text(self.title)
                .font(.footnote)
                .foregroundColor(.secondary)
            if let url = URL(string: Const.SERVER_GITHUB_URL){
                Link(destination: url){
                    Label(Const.SERVER_GITHUB_URL.replacingOccurrences(of: "https://", with: ""), systemImage: "link")
                        .font(.footnote)
                }
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#Preview {
    ServerGithubLink("还没有服务器？可以按照这里的说明部署")
}
