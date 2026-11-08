//
//  ProfilePage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

struct ProfilePage: View {

    @StateObject private var vm = ProfileViewModel()

    /// 显示图片选择器
    @State private var showImagePicker = false

    /// 显示注销账号的密码输入框
    @State private var showUnregisterAlert = false

    var body: some View {
        SettingStack(embedInNavigationStack: false) {
            SettingPage(title:"个人资料") {
                SettingCustomView{
                    Button(action:{
                        self.showImagePicker = true
                    }){
                        VStack(spacing: 8){
                            UserAvatar(self.vm.user?.logo, size: 80)
                            Text("更换头像").font(.footnote).foregroundColor(.secondary)
                        }
                        .padding(32)
                    }.frame(maxWidth: .infinity)
                }
                SettingGroup{
                    SettingTextField(title: "昵称", text: self.$vm.nick, placeholder: "请输入昵称")
                    if self.vm.user?.isTemp == true{
                        SettingNavigationLink("绑定邮箱",tip: "绑定之后可以用邮箱登录"){
                            EmailCodePage(.bindEmail).anyView
                        }
                    } else {
                        SettingText(title: "邮箱：" + (self.vm.user?.email ?? ""))
                    }
                }
                SettingGroup{
                    SettingButtonSingle("保存昵称",action: self.vm.onSaveNickClick)
                }
                if self.vm.user?.isTemp == false{
                    SettingGroup(footer: "注销之后歌单都会删除,邮箱可以重新注册"){
                        SettingButtonSingle("注销账号"){
                            self.vm.unregisterPwd = ""
                            self.showUnregisterAlert = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: self.$showImagePicker) {
            SingleImagePicker(isPresented: self.$showImagePicker, onPick: self.vm.onAvatarPick)
        }
        .alert("注销账号", isPresented: self.$showUnregisterAlert){
            SecureField("请输入密码", text: self.$vm.unregisterPwd)
            Button("注销", role: .destructive, action: self.vm.onUnregisterClick)
            Button("取消", role: .cancel){}
        } message: {
            Text("注销之后不能恢复,请输入密码确认")
        }
    }
}

#Preview {
    ProfilePage()
}
