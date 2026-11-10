//
//  MineViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

class MineViewModel: ObservableObject {

    /// 当前登录的账号信息
    @Published var logged: AccountInfo?

    /// 当前登录的会员信息
    @Published var user = SettingShared.user

    /// 目标音质
    @Published var bitRate = SettingShared.bitRate

    init() {
        self.logged = SettingShared.loggedUser
    }

    /// 显示的名字
    var displayName: String {
        if let nick = self.user?.nick, !nick.isEmpty{
            return nick
        }
        return self.logged?.name ?? ""
    }

    /// 刷新会员信息,昵称和头像可能在其他设备上修改过
    func loadUser(){
        self.user = SettingShared.user
        SettingShared.loadUserInBackground{
            self.user = $0
            self.logged = SettingShared.loggedUser
        }
    }

    /// 修改播放音质,歌曲里有所有音质的文件,每首歌开始播放前按设置选择,不用重新获取歌单
    func onBitRateChange(_ bitRate: Int) -> Bool{
        SettingShared.bitRate = bitRate
        return true
    }

    /// 退出登录点击事件
    func onLogoutClick(){

        //让服务端删除这个票据
        UserApi.logout().hide().send{}
        SettingShared.logout()
        ServerPage().relaunch()
    }
}
