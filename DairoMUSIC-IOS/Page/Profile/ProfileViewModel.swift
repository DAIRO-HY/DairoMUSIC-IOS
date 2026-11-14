//
//  ProfileViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

class ProfileViewModel: ObservableObject {

    /// 当前登录的会员信息
    @Published var user = SettingStore.user

    /// 昵称
    @Published var nick = SettingStore.user?.nick ?? ""

    /// 注销账号时验证的密码
    @Published var unregisterPwd = ""

    /// 保存昵称点击事件
    func onSaveNickClick(){
        let nick = self.nick.trim()
        if nick.isEmpty{
            Toast.show("请输入昵称")
            return
        }
        UserApi.edit(nick: nick).send {
            Toast.show("保存成功")
            self.loadUser()
        }
    }

    /// 选择头像之后上传
    func onAvatarPick(_ image: UIImage){
        guard let jpeg = image.toUploadJpeg() else{
            Toast.show("读取图片失败")
            return
        }
        UserApi.avatar(jpeg: jpeg).send { _ in
            self.loadUser()
        }
    }

    /// 注销账号点击事件
    func onUnregisterClick(){
        UserApi.unregister(pwd: self.unregisterPwd).send{
            Toast.show("账号已注销")
            let account = SettingStore.currentAccount
            SettingStore.logout()

            //注销之后这个账号不能再登录,从已登录列表里删除
            if let account{
                SettingStore.accountList = SettingStore.accountList.filter{ !$0.isSame(account) }
            }
            ServerPage().relaunch()
        }
    }

    /// 刷新会员信息
    private func loadUser(){
        SettingStore.loadUserInBackground{
            self.user = $0
        }
    }
}
