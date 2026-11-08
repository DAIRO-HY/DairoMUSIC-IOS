//
//  EventName.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import Foundation

/// 全局通知名,都在主线程发送
enum EventName {

    /// 我的歌单发生了变化
    static let FAVORITE_CHANGE = Notification.Name("FAVORITE_CHANGE")

    /// 我的歌单里的歌曲发生了变化
    static let MUSIC_CHANGE = Notification.Name("MUSIC_CHANGE")

    /// 最近播放发生了变化
    static let LATE_CHANGE = Notification.Name("LATE_CHANGE")

    /// 定时停止播放的时间到了
    static let SLEEP_TIMER_END = Notification.Name("SLEEP_TIMER_END")
}
