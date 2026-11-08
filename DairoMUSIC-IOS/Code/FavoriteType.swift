//
//  FavoriteType.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

/// 播放列表的来源,大于0时为歌单ID
enum FavoriteType {

    /// 没有来源,例如首页推荐的单曲
    static let NONE: Int64 = 0

    /// 来自搜索页面
    static let SEARCH: Int64 = -1

    /// 来自最近播放
    static let LATE: Int64 = -2
}
