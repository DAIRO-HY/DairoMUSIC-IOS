//
//  ServerPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/08.
//

import SwiftUI
import DairoUI_IOS

/// 登录的第一步:输入服务器地址,确认是DairoMUSIC服务器之后进入登录页面
struct ServerPage: View {

    //系统弹窗等导致App状态变化时,页面会重新创建,必须用StateObject才能保留已输入的内容
    @StateObject private var vm: LoginViewModel

    init(_ vm: LoginViewModel = LoginViewModel(domain: SettingShared.domainNotNull)) {
        self._vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationView{
            SettingStack(embedInNavigationStack: false) {
                SettingPage(title: "服务器") {
                    SettingCustomView {
                        ZStack{
                            Image("logo")
                                .resizable()
                                .frame(width: 80, height: 80)
                                .cornerRadius(14)   // 设置圆角半径
                                .padding(32)
                        }.frame(maxWidth: .infinity)
                    }
                    SettingGroup(footer: "请输入DairoMUSIC服务器的地址，例如 192.168.1.100:8020、https://music.example.com。没有写http://或https://时按http://连接", allowAttributedFooter: false){
                        SettingTextField(title: "服务器", text: self.$vm.domain, placeholder: "例 192.168.1.100:8020")
                    }
                    SettingGroup{
                        SettingButtonSingle("下一步", action: self.vm.onNextClick)
                    }
                    SettingCustomView {
                        HStack{
                            Button(action: {
                                LoggedPage(embedInNavigationStack: true).relaunch()
                            }){
                                Text("选择账号")
                            }
                            Spacer()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    }
                }
            }
            .onSubmit(self.vm.onNextClick)

            //固定显示在屏幕最底部,输入服务器地址时隐藏
            .overlay(alignment: .bottom){
                ServerGithubLink("还没有服务器？可以按照这里的说明部署")
            }
            .background(
                NavigationLink(destination: LoginPage(self.vm, isRoot: false), isActive: self.$vm.showLogin){
                    EmptyView()
                }
            )
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    ServerPage()
}
