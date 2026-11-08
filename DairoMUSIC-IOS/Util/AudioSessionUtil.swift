//
//  AudioSessionUtil.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import AVFoundation

/**
 统一管理音频会话,App启动时不占用音频,避免打断其他App正在播放的音乐
 */
enum AudioSessionUtil {

    /// 播放歌曲时独占音频,其他App的声音会被暂停,静音模式下也有声音,支持后台播放
    static func exclusive() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
    }

    /// 停止播放后释放音频,通知其他App可以恢复播放
    static func release() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
