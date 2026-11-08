//
//  EmailCodePage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

/// 注册、重置密码、绑定邮箱,都需要邮箱验证码
struct EmailCodePage: View {

    @StateObject private var vm: EmailCodeViewModel

    init(_ type: EmailCodeType, domain: String = "") {
        self._vm = StateObject(wrappedValue: EmailCodeViewModel(type, domain: domain))
    }

    var body: some View {
        SettingStack(embedInNavigationStack: false) {
            SettingPage(title: self.vm.type.title) {
                if self.vm.type != .bindEmail{
                    SettingCustomView{
                        ServerLabel(self.vm.domain).frame(maxWidth: .infinity)
                    }
                }
                SettingGroup(footer: self.vm.type == .bindEmail ? "绑定之后可以使用邮箱和密码登录,歌单都会保留" : nil){
                    SettingTextField(title: "邮箱", text: self.$vm.email, placeholder: "请输入邮箱")
                    SettingCustomView{
                        HStack{
                            Text("验证码")
                            TextField("请输入验证码", text: self.$vm.code)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Button(action: self.vm.onSendCodeClick){
                                Text(self.vm.countdown > 0 ? "\(self.vm.countdown)秒" : "发送验证码")
                                    .font(.subheadline)
                                    .frame(minWidth: 72)
                            }
                            .buttonStyle(.borderless)
                            .disabled(self.vm.countdown > 0)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 11)
                    }
                    SettingTextField(title: self.vm.type == .resetPwd ? "新密码" : "密码", text: self.$vm.pwd, placeholder: "6~32位", type: .password)
                    SettingTextField(title: "确认密码", text: self.$vm.repwd, placeholder: "请再次输入密码", type: .password)
                }
                SettingGroup{
                    SettingButtonSingle(self.vm.type.title, action: self.vm.onSubmitClick)
                }
            }
        }
    }
}

#Preview {
    EmailCodePage(.register)
}
