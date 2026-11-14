//
//  LoggedPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

struct LoggedPage: View {

    ///操作按钮菜单显示
    @State private var showActionMenu = false

    /// 显示确认删除框
    @State private var showDeleteAlert = false

    @StateObject private var vm = LoggedViewModel()
    private let embedInNavigationStack: Bool
    init(embedInNavigationStack: Bool = false){
        self.embedInNavigationStack = embedInNavigationStack
    }

    var body: some View {
        SettingStack(embedInNavigationStack: self.embedInNavigationStack) {
            SettingPage(title:"选择账号") {
                SettingCustomView{
                    ZStack{
                        Image("logo")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(14)   // 设置圆角半径
                            .padding(32)
                    }.frame(maxWidth: .infinity)
                }
                SettingGroup{
                    SettingCustomView{
                        ForEach(self.vm.loggedUserList.indices, id: \.self){ i in
                            let item = self.vm.loggedUserList[i]
                            Button(action:{
                                self.vm.actionIndex = i
                                self.showActionMenu = true
                            }){
                                HStack{
                                    VStack{
                                        Text(item.name).foregroundColor(.primary).frame(maxWidth: .infinity, alignment: .leading)
                                        Text(item.domain).font(.subheadline).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                                    }.frame(maxWidth: .infinity)
                                    Image(systemName: "checkmark").foregroundColor(.primary).opacity(item.isLogining ? 1 : 0.3)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                        }
                    }
                }
                SettingGroup{
                    SettingButtonSingle("添加账号"){
                        ServerPage().relaunch()
                    }
                }
            }
        }
        .alert("确认删除吗？", isPresented: self.$showDeleteAlert) {
            Button("删除", role: .destructive) {
                self.vm.onDeleteClick()

                //退出登录,让服务端删除这个票据
                UserApi.logout().hide().send{}
                SettingShared.logout()

                //删除之后重新打开该页面
                LoggedPage(embedInNavigationStack: true).relaunch()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("该账户处于登录状态，删除后将会退出登录。")
        }
        .confirmationDialog("请选择操作", isPresented: self.$showActionMenu, titleVisibility: .visible) {
            Button("登录") {
                self.onSwitchAccount(self.vm.actionItem)
            }
            Button("编辑") {
                let actionItem = self.vm.actionItem
                LoginPage(LoginViewModel(domain: actionItem.domain, account: actionItem.account, editLoggedIndex: self.vm.actionIndex)).relaunch()
            }
            Button("复制") {
                let actionItem = self.vm.actionItem
                LoginPage(LoginViewModel(domain: actionItem.domain, account: actionItem.account)).relaunch()
            }
            Button("移除") {
                let actionItem = self.vm.actionItem
                if actionItem.isLogining{
                    self.showDeleteAlert = true
                } else {
                    self.vm.onDeleteClick()

                    //重新加载数据
                    self.vm.loadData()
                }
            }
            Button("取消", role: .cancel) { }
        }
    }

    /// 切换到选择的账号
    private func onSwitchAccount(_ account: AccountInfo){
        if account.token.isEmpty{//账号已经退出登录,需要重新输入密码
            LoginPage(LoginViewModel(domain: account.domain, account: account.account)).relaunch()
            return
        }
        SettingShared.switchAccount(account, success:{
            Toast.show("登录成功")
            DiscoverPage().relaunch()
        })
    }
}

#Preview {
    LoggedPage()
}
