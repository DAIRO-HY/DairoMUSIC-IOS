//
//  LoginPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

/// 登录的第二步:服务器已经确定,输入邮箱或用户名和密码
struct LoginPage: View {

    //系统弹窗等导致App状态变化时,页面会重新创建,必须用StateObject才能保留已输入的内容
    @StateObject private var vm: LoginViewModel

    /// 是否直接作为根页面打开(登录失效、编辑账号),这时没有上一页,要显示更换服务器
    private let isRoot: Bool

    init(_ vm: LoginViewModel, isRoot: Bool = true) {
        self._vm = StateObject(wrappedValue: vm)
        self.isRoot = isRoot
    }

    var body: some View {
        if self.isRoot{
            NavigationView{
                self.content
            }
            .navigationViewStyle(.stack)
        } else {
            self.content
        }
    }

    private var content: some View {
        SettingStack(embedInNavigationStack: false) {
            SettingPage(title: self.vm.editLoggedIndex == nil ? "登录" : "编辑账号") {
                SettingCustomView {
                    VStack(spacing: 12){
                        Image("logo")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(14)   // 设置圆角半径
                        ServerLabel(self.vm.domain)
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                }
                SettingGroup{
                    SettingTextField(title: "账号", text: self.$vm.account, placeholder: "邮箱或用户名")
                    SettingTextField(title: "密码", text: self.$vm.pwd, placeholder: "请输入密码", type: .password)
                }
                SettingGroup{
                    SettingButtonSingle(self.vm.editLoggedIndex == nil ? "登录" : "保存",action: self.vm.onLoginClick)
                }
                SettingCustomView {

                    //注册在最左边,忘记密码在最右边,更换服务器在正中间
                    HStack(spacing: 0){
                        Group{
                            if self.vm.allowRegister == true{
                                NavigationLink(destination: EmailCodePage(.register, domain: self.vm.domain)){
                                    Text("注册")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Group{
                            if self.isRoot{
                                Button(action: {
                                    ServerPage(LoginViewModel(domain: self.vm.domain, account: self.vm.account, editLoggedIndex: self.vm.editLoggedIndex)).relaunch()
                                }){
                                    Text("更换服务器")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        NavigationLink(destination: EmailCodePage(.resetPwd, domain: self.vm.domain)){
                            Text("忘记密码")
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    //左右和上面的输入框对齐
                    .padding(.horizontal, 20)

                    //和下面的"免注册使用"拉开距离
                    .padding(.bottom, 24)
                }
                if self.vm.allowRegister == true{
                    SettingGroup(footer: "不注册也可以使用,之后可以在个人资料里绑定邮箱"){
                        SettingButtonSingle("免注册使用",action: self.vm.onTempLoginClick)
                    }
                }
            }
        }

        //小屏手机上键盘会挡住登录按钮,信息都填好时按键盘上的回车直接登录
        .onSubmit {
            if !self.vm.account.isEmpty && !self.vm.pwd.isEmpty{
                self.vm.onLoginClick()
            }
        }
        .onAppear(perform: self.vm.loadConfig)
    }
}

/// 服务器地址标签,登录、注册、忘记密码页面显示当前要登录的服务器
struct ServerLabel: View {

    private let domain: String

    init(_ domain: String) {
        self.domain = domain
    }

    var body: some View {
        Label(self.domain, systemImage: "server.rack")
            .font(.footnote)
            .foregroundColor(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
    }
}

#Preview {
    LoginPage(LoginViewModel(domain: "http://127.0.0.1:8020"))
}
