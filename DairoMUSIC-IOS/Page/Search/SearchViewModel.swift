//
//  SearchViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

class SearchViewModel: ObservableObject {

    /// 搜索历史的本地缓存名
    private static let _KEY_HISTORY = "search_history"

    /// 最多保存的搜索历史数
    private static let MAX_HISTORY_COUNT = 20

    /// 搜索关键词
    @Published var key = ""

    /// 曲库的搜索结果
    @Published var musicList = [MusicModel]()

    /// 采集平台的搜索结果
    @Published var collectList = [MusicModel]()

    /// 是否正在搜索采集平台
    @Published var isCollectSearching = false

    /// 是否已经搜索过,没有搜索时显示搜索历史
    @Published var isSearched = false

    /// 搜索历史
    @Published var history = [String]()

    /// 上一次的请求,重新搜索时取消
    private var requests = [ApiHttpBase]()

    init() {
        self.history = SettingShared.accountObjectName(SearchViewModel._KEY_HISTORY).flatMap{ LocalObjectUtil.read([String].self, $0) } ?? []
    }

    /// 搜索,曲库和采集平台同时搜索,曲库的结果先显示
    func search(){
        let key = self.key.trim()
        if key.isEmpty{
            return
        }
        self.addHistory(key)
        self.requests.forEach{ $0.cancel() }
        self.isSearched = true
        self.musicList = []
        self.collectList = []
        self.isCollectSearching = true
        let musicRequest = MusicApi.search(key: key).send{
            self.musicList = $0
        }
        let collectRequest = MusicApi.searchCollect(key: key).hide().fail{ _ in
        }.error{ _ in
        }.finish{
            self.isCollectSearching = false
        }.send{
            self.collectList = $0
        }
        self.requests = [musicRequest, collectRequest]
    }

    /// 点击搜索历史
    func onHistoryClick(_ key: String){
        self.key = key
        self.search()
    }

    /// 关键词清空时回到搜索历史
    func onKeyChange(){
        if self.key.isEmpty{
            self.isSearched = false
        }
    }

    /// 播放搜索结果
    func play(_ list: [MusicModel], index: Int){
        PlayerManager.shared.prepareAndPlay(list, index: index, favoriteId: FavoriteType.SEARCH)
    }

    /// 添加到搜索历史
    private func addHistory(_ key: String){
        self.history.removeAll{ $0 == key }
        self.history.insert(key, at: 0)
        if self.history.count > SearchViewModel.MAX_HISTORY_COUNT{
            self.history.removeLast(self.history.count - SearchViewModel.MAX_HISTORY_COUNT)
        }
        self.saveHistory()
    }

    /// 清空搜索历史
    func onClearHistoryClick(){
        self.history = []
        self.saveHistory()
    }

    private func saveHistory(){
        if let name = SettingShared.accountObjectName(SearchViewModel._KEY_HISTORY){
            _ = LocalObjectUtil.write(self.history, name)
        }
    }
}
