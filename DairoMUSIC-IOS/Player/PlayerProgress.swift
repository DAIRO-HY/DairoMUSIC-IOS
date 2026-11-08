//
//  PlayerProgress.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import Foundation

/// 播放进度,变化很频繁,和播放器的其他状态分开,避免歌曲列表跟着刷新
final class PlayerProgress: ObservableObject {

    static let shared = PlayerProgress()

    /// 当前播放位置(秒)
    @Published var currentTime = 0.0

    /// 歌曲总时长(秒),还没加载出来时为0
    @Published var duration = 0.0

    /// 是否正在拖动进度条,拖动时不更新播放位置
    var isDragging = false

    private init() {}
}
