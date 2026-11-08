//
//  MusicListViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import Combine
import DairoUI_IOS

class MusicListViewModel: ObservableObject {

    /// 歌单ID,最近播放时为FavoriteType.LATE
    let favoriteId: Int64

    /// 歌单名
    @Published var name: String

    /// 歌单描述
    @Published var description: String?

    /// 封面
    @Published var logo: String?

    /// 歌曲列表
    @Published var musicList = [MusicModel]()

    /// 是否正在从服务器加载
    @Published var isLoading = false

    /// 是否我的歌单,可以删除里面的歌曲
    @Published var isMine = false

    /// 是否"我喜欢"歌单,不能修改
    @Published var isLike = false

    private var cancellables = Set<AnyCancellable>()

    init(favoriteId: Int64, name: String) {
        self.favoriteId = favoriteId
        self.name = name
        if favoriteId == FavoriteType.LATE{
            NotificationCenter.default.publisher(for: EventName.LATE_CHANGE).sink{ [weak self] _ in
                self?.loadData()
            }.store(in: &self.cancellables)
        } else {
            NotificationCenter.default.publisher(for: EventName.MUSIC_CHANGE).merge(with: NotificationCenter.default.publisher(for: EventName.FAVORITE_CHANGE)).sink{ [weak self] _ in
                self?.loadData()
            }.store(in: &self.cancellables)
        }
        self.loadData()
        if self.isMine{

            //我的歌单先显示本地缓存,再从服务器更新
            MusicShared.loadInBackground()
        }
    }

    /// 加载数据
    func loadData(){
        if self.favoriteId == FavoriteType.LATE{
            self.musicList = MusicShared.lateMusic
            return
        }
        if let favorite = FavoriteShared.byId(self.favoriteId){//我的歌单
            self.isMine = true
            self.isLike = favorite.isLike
            self.name = favorite.name
            self.description = favorite.description
            self.logo = favorite.logo
            self.musicList = MusicShared.musics(favoriteId: self.favoriteId)
            return
        }
        if self.isMine || self.isLoading{
            return
        }

        //推荐的歌单从服务器获取
        self.isLoading = true
        FavoriteApi.detail(id: self.favoriteId).hide().send{ favorite in
            self.name = favorite.name
            self.description = favorite.description
            self.logo = favorite.logo
        }
        FavoriteApi.musics(id: self.favoriteId).hide().finish{
            self.isLoading = false
        }.send{
            self.musicList = $0
        }
    }

    /// 播放列表里的歌曲
    func play(_ index: Int){
        PlayerManager.shared.prepareAndPlay(self.musicList, index: index, favoriteId: self.favoriteId)
    }

    /// 从歌单删除歌曲
    func remove(_ music: MusicModel){
        FavoriteShared.removeMusic(musicId: music.id, favoriteId: self.favoriteId){
            Toast.show("已删除")
        }
    }

    /// 清空最近播放
    func clearLate(){
        MusicShared.clearLate()
    }
}
