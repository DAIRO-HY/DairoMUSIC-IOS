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
    @Published var account: AccountInfo?

    /// 当前登录的会员信息
    @Published var user = SettingStore.user

    /// 目标音质
    @Published var bitRate = SettingStore.bitRate

    init() {
        self.account = SettingStore.currentAccount
    }

    /// 显示的名字
    var displayName: String {
        if let nick = self.user?.nick, !nick.isEmpty{
            return nick
        }
        return self.account?.name ?? ""
    }

    /// 刷新会员信息,昵称和头像可能在其他设备上修改过
    func loadUser(){
        self.user = SettingStore.user
        SettingStore.loadUserInBackground{
            self.user = $0
            self.account = SettingStore.currentAccount
        }
    }

    /// 修改播放音质,歌曲里有所有音质的文件,每首歌开始播放前按设置选择,不用重新获取歌单
    /// 非VIP只能选标准音质,不保存,保留自己设置的音质,开通VIP之后恢复
    func onBitRateChange(_ bitRate: Int) -> Bool{
        if ServerConfig.shared.isVipLimited{
            if bitRate > SettingStore.BIT_RATE_STANDARD{
                Toast.show("超高品质、无损音质需要VIP")
                return false
            }
            return true
        }
        SettingStore.bitRate = bitRate
        return true
    }

    /// 退出登录点击事件
    func onLogoutClick(){

        //让服务端删除这个票据
        UserApi.logout().hide().send{}
        SettingStore.logout()
        ServerPage().relaunch()
    }
}
