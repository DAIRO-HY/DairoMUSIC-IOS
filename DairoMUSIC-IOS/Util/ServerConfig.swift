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

    /// 是否允许下载视频
    @Published private(set) var allowDownloadVideo = false

    /// 是否允许把下载的视频保存到相册,允许下载视频时才有效
    @Published private(set) var allowSaveAlbum = false

    /// 是否允许下载歌曲
    @Published private(set) var allowDownloadMusic = false

    /// 服务器是否开启了视频采集,获取到配置之前按开启处理
    @Published private(set) var videoEnable = true

    /// 当前会员的VIP状态,会员信息保存时更新;没有登录、老版本的会员信息里没有时为nil,按VIP功能没有生效处理
    @Published private(set) var vip: VipModel?

    private init() {
        self.vip = SettingShared.user?.vip
    }

    /// VIP功能对当前会员是否生效,没有生效时不显示任何VIP相关的内容
    var isVipEnable: Bool {
        return self.vip?.enable == true
    }

    /// 是否受非VIP的限制:只能听标准音质、看流畅版视频,不能下载
    var isVipLimited: Bool {
        guard let vip = self.vip else{
            return false
        }
        return vip.enable && !vip.isVip
    }

    /// 点击下载时检查VIP:服务器允许下载时显示下载按钮,非VIP点击时提示需要开通VIP
    /// - Returns: 是否可以下载
    func checkDownloadVip() -> Bool {
        if self.isVipLimited{
            Toast.show("下载需要开通VIP")
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
        if !SettingShared.isLogin{
            return
        }
        CommonApi.config().hide().fail{ _ in
        }.error{ _ in
        }.send{ [weak self] config in
            self?.allowDownloadVideo = config.allowDownloadVideo
            self?.allowSaveAlbum = config.allowSaveAlbum
            self?.allowDownloadMusic = config.allowDownloadMusic
            self?.videoEnable = config.videoEnable
        }
    }
}
