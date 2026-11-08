//
//  PlayerOrderType.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

/// 播放顺序
enum PlayerOrderType: String, Codable {

    /// 列表循环
    case LIST_LOOP

    /// 随机播放
    case RANDOM_LOOP

    /// 单曲循环
    case ONE_LOOP

    /// 图标
    var icon: String {
        switch self {
        case .LIST_LOOP:
            return "repeat"
        case .RANDOM_LOOP:
            return "shuffle"
        case .ONE_LOOP:
            return "repeat.1"
        }
    }

    /// 说明
    var label: String {
        switch self {
        case .LIST_LOOP:
            return "列表循环"
        case .RANDOM_LOOP:
            return "随机播放"
        case .ONE_LOOP:
            return "单曲循环"
        }
    }

    /// 下一种播放顺序
    var next: PlayerOrderType {
        switch self {
        case .LIST_LOOP:
            return .RANDOM_LOOP
        case .RANDOM_LOOP:
            return .ONE_LOOP
        case .ONE_LOOP:
            return .LIST_LOOP
        }
    }
}
