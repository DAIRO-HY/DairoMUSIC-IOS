//
//  ServerConfig.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/08.
//

import Foundation

/// 服务器的配置,进入首页和App回到前台时刷新,管理后台修改之后不用重新登录
class ServerConfig: ObservableObject {

    static let shared = ServerConfig()

    /// 是否允许下载视频
    @Published private(set) var allowDownloadVideo = false

    /// 是否允许把下载的视频保存到相册,允许下载视频时才有效
    @Published private(set) var allowSaveAlbum = false

    /// 是否允许下载歌曲
    @Published private(set) var allowDownloadMusic = false

    private init() {
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
        }
    }
}
