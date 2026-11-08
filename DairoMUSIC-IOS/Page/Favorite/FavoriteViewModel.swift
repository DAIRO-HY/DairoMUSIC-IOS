//
//  FavoriteViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import Combine
import DairoUI_IOS

class FavoriteViewModel: ObservableObject {

    /// "我喜欢"歌单
    @Published var likeFavorite: FavoriteModel?

    /// 自己创建的歌单
    @Published var userFavorites = [FavoriteModel]()

    /// 最近播放的歌曲数
    @Published var lateCount = 0

    /// 新建歌单的名字
    @Published var createName = ""

    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: EventName.FAVORITE_CHANGE).sink{ [weak self] _ in
            self?.loadData()
        }.store(in: &self.cancellables)
        NotificationCenter.default.publisher(for: EventName.LATE_CHANGE).sink{ [weak self] _ in
            self?.lateCount = MusicShared.lateMusic.count
        }.store(in: &self.cancellables)
        self.loadData()
        self.lateCount = MusicShared.lateMusic.count

        //先显示本地缓存,再从服务器更新
        FavoriteShared.loadInBackground()
    }

    /// 加载本地的歌单
    private func loadData(){
        let list = FavoriteShared.list
        self.likeFavorite = list.first{ $0.isLike }
        self.userFavorites = list.filter{ !$0.isLike }
    }

    /// 新建歌单
    func onCreateClick(){
        let name = self.createName.trim()
        if name.isEmpty{
            Toast.show("请输入歌单名")
            return
        }
        FavoriteApi.add(name: name).send{ _ in
            Toast.show("创建成功")
            FavoriteShared.loadInBackground()
        }
    }

    /// 删除歌单
    func onDeleteClick(_ favorite: FavoriteModel){
        FavoriteApi.delete(id: favorite.id).send{
            Toast.show("删除成功")
            FavoriteShared.loadInBackground()
            MusicShared.loadInBackground()
        }
    }

    /// 拖动排序之后保存,"我喜欢"始终排在最前面
    func onMove(from: IndexSet, to: Int){
        self.userFavorites.move(fromOffsets: from, toOffset: to)
        var ids = self.userFavorites.map{ $0.id }
        if let like = self.likeFavorite{
            ids.insert(like.id, at: 0)
        }
        FavoriteApi.sort(ids: ids).hide().send{
            FavoriteShared.loadInBackground()
        }
    }
}
