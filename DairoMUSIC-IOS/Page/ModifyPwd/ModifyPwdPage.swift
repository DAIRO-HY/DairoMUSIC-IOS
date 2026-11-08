//
//  ModifyPwdPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

struct ModifyPwdPage: View {

    //密码信息
    @StateObject private var vm = ModifyPwdViewModel()

    var body: some View {
        SettingStack(embedInNavigationStack: false) {
            SettingPage(title:"修改密码") {
                SettingGroup(footer: "修改之后其他设备需要重新登录"){
                    SettingTextField(title: "旧密码", text: self.$vm.oldPwd, placeholder: "请输入当前密码", type: .password)
                    SettingTextField(title: "新密码", text: self.$vm.pwd, placeholder: "6~32位", type: .password)
                    SettingTextField(title: "确认密码", text: self.$vm.repwd, placeholder: "请确认新密码", type: .password)
                }
                SettingGroup{
                    SettingButtonSingle("修改",action: self.vm.onModifyClick)
                }
            }
        }
    }
}
