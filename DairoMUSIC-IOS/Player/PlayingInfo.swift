//
//  PlayingInfo.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

/// 保存到本地的播放信息,App重启之后恢复
struct PlayingInfo: Codable {

    /// 播放列表
    var playList = [MusicModel]()

    /// 当前播放的序号
    var index = 0

    /// 播放列表的来源,参考FavoriteType
    var favoriteId = FavoriteType.NONE

    /// 当前播放位置(秒)
    var currentTime = 0.0

    /// 播放顺序
    var orderType = PlayerOrderType.LIST_LOOP
}
