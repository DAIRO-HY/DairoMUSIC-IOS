//
//  LrcViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import Combine
import DairoUI_IOS

class LrcViewModel: ObservableObject {

    /// 歌词
    @Published var lines = [LrcLine]()

    /// 没有歌词时的提示
    @Published var tip: String? = nil

    /// 当前显示歌词的歌曲ID
    private var musicId: Int64?

    /// 获取歌词的请求
    private var request: ApiHttpBase?

    private var cancellables = Set<AnyCancellable>()

    init() {
        PlayerManager.shared.$playList.combineLatest(PlayerManager.shared.$index).receive(on: DispatchQueue.main).sink{ [weak self] _ in

            //播放列表的值还没有更新,等下一次运行循环再读取当前歌曲
            DispatchQueue.main.async {
                self?.load()
            }
        }.store(in: &self.cancellables)
    }

    /// 加载当前歌曲的歌词
    private func load(){
        let music = PlayerManager.shared.music
        if music?.id == self.musicId && (!self.lines.isEmpty || self.tip != nil){
            return
        }
        self.musicId = music?.id
        self.request?.cancel()
        self.lines = []
        guard let music, music.id != 0 else{
            self.tip = "暂无歌词"
            return
        }
        self.tip = "歌词加载中"
        let cacheName = SettingShared.accountObjectName("lrc_\(music.id)")
        if let lrc = cacheName.flatMap({ LocalObjectUtil.read(String.self, $0) }){
            self.show(lrc)
            return
        }
        self.request = MusicApi.lrc(id: music.id).hide().fail{ [weak self] _ in
            self?.tip = "歌词加载失败"
        }.error{ [weak self] _ in
            self?.tip = "歌词加载失败"
        }.send{ [weak self] list in
            guard let self, self.musicId == music.id else{
                return
            }
            let lrc = list.first?.lrc ?? ""
            if let cacheName{
                _ = LocalObjectUtil.write(lrc, cacheName)
            }
            self.show(lrc)
        }
    }

    /// 显示歌词
    private func show(_ lrc: String){
        self.lines = LrcParser.parse(lrc)
        self.tip = self.lines.isEmpty ? "暂无歌词" : nil
    }

    /// 获取当前时间应该高亮的歌词序号
    func currentIndex(_ time: Double) -> Int? {
        return self.lines.lastIndex{ $0.time <= time }
    }
}
