//
//  ServerConfig.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/08.
//

import Foundation
import DairoUI_IOS

/// 服务器的配置和当前会员的VIP状态,进入首页和App回到前台时刷新,管理后台修改之后不用重新登录
class ServerConfig: ObservableObject {

    static let shared = ServerConfig()

    /// 是否允许把下载的视频保存到相册,不允许时不显示入口;VIP功能生效时只有VIP才能用
    @Published private(set) var allowSaveAlbum = false

    /// 是否允许发送下载的歌曲、视频文件,不允许时不显示入口;VIP功能生效时只有VIP才能用
    @Published private(set) var allowSendFile = false

    /// 服务器是否开启了视频采集,获取到配置之前按开启处理
    @Published private(set) var videoEnable = true

    /// 当前会员的VIP状态,会员信息保存时更新;没有登录时为nil,按VIP功能没有生效处理
    @Published private(set) var vip: VipModel?

    private init() {
        self.vip = SettingStore.user?.vip
    }

    /// VIP功能对当前会员是否生效,没有生效时不显示任何VIP相关的内容
    var isVipEnable: Bool {
        return self.vip?.enable == true
    }

    /// 是否受非VIP的限制:只能听、下载标准音质和流畅版视频,不能发送文件、保存到相册
    var isVipLimited: Bool {
        guard let vip = self.vip else{
            return false
        }
        return vip.enable && !vip.isVip
    }

    /// 文件出App(发送文件、保存到相册)是VIP特权,非VIP点击时提示需要开通VIP
    /// - Parameter action: 提示里的操作名称,例如"发送文件"
    /// - Returns: 是否可以继续
    func checkFileOutVip(_ action: String) -> Bool {
        if self.isVipLimited{
            Toast.show(action + "需要开通VIP")
            return false
        }
        return true
    }

    /// 更新VIP状态
    func updateVip(_ vip: VipModel?) {
        if Thread.isMainThread{
            self.vip = vip
        } else {
            DispatchQueue.main.async{
                self.vip = vip
            }
        }
    }

    /// 从服务器获取配置,没有登录时不处理
    func load() {
        if !SettingStore.isLogin{
            return
        }
        CommonApi.config().hide().fail{ _ in
        }.error{ _ in
        }.send{ [weak self] config in
            self?.allowSaveAlbum = config.allowSaveAlbum
            self?.allowSendFile = config.allowSendFile
            self?.videoEnable = config.videoEnable
        }
    }
}
