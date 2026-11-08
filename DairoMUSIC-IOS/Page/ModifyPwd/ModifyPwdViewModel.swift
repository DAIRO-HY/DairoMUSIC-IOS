//
//  ModifyPwdViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

class ModifyPwdViewModel: ObservableObject {

    /// 旧密码
    @Published var oldPwd = ""

    /// 新密码
    @Published var pwd = ""

    /// 确认新密码
    @Published var repwd = ""

    /// 修改按钮点击事件
    func onModifyClick(){
        if self.oldPwd.isEmpty{
            Toast.show("请输入旧密码")
            return
        }
        if self.pwd.count < 6 || self.pwd.count > 32{
            Toast.show("新密码长度为6~32位")
            return
        }
        if self.pwd != self.repwd{
            Toast.show("确认密码和新密码不一致")
            return
        }
        UserApi.modifyPwd(oldPwd: self.oldPwd, pwd: self.pwd).send {
            Toast.show("修改成功")
            self.oldPwd = ""
            self.pwd = ""
            self.repwd = ""
        }
    }
}
