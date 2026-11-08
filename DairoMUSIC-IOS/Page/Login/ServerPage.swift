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
                    SettingGroup(footer: "请输入DairoMUSIC服务器的地址,默认端口是\(Const.DEFAULT_PORT)"){
                        SettingTextField(title: "服务器", text: self.$vm.domain, placeholder: "例 192.168.1.100:\(Const.DEFAULT_PORT)")
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
