//
//  DiscoverViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

class DiscoverViewModel: ObservableObject {

    /// 轮播的本地缓存名
    private static let _KEY_SWIPER = "discover_swiper"

    /// 推荐歌单的本地缓存名
    private static let _KEY_USEFUL = "discover_useful"

    /// 轮播
    @Published var swiperList = [SwiperModel]()

    /// 推荐歌单分组
    @Published var usefulList = [UsefulModel]()

    /// 当前显示的轮播序号
    @Published var swiperIndex = 0

    init() {

        //先显示本地缓存,再从服务器更新
        self.swiperList = SettingShared.accountObjectName(DiscoverViewModel._KEY_SWIPER).flatMap{ LocalObjectUtil.read([SwiperModel].self, $0) } ?? []
        self.usefulList = SettingShared.accountObjectName(DiscoverViewModel._KEY_USEFUL).flatMap{ LocalObjectUtil.read([UsefulModel].self, $0) } ?? []
        self.loadData()

        //进入首页时在后台刷新我的歌单,其他页面用到时已经是最新的
        FavoriteShared.loadInBackground()
        MusicShared.loadInBackground()
    }

    /// 从服务器加载数据
    func loadData(){

        //登录、切换账号之后进入首页时刷新服务器配置
        ServerConfig.shared.load()
        HomeApi.swiper().hide().send{
            self.swiperList = $0
            if let name = SettingShared.accountObjectName(DiscoverViewModel._KEY_SWIPER){
                _ = LocalObjectUtil.write($0, name)
            }
        }
        HomeApi.useful().hide().send{
            self.usefulList = $0
            if let name = SettingShared.accountObjectName(DiscoverViewModel._KEY_USEFUL){
                _ = LocalObjectUtil.write($0, name)
            }
        }
    }

    /// 自动滚动到下一张轮播
    func nextSwiper(){
        guard self.swiperList.count > 1 else{
            return
        }
        withAnimation {
            self.swiperIndex = (self.swiperIndex + 1) % self.swiperList.count
        }
    }

    /// 轮播点击事件,推荐歌单在页面里跳转,这里处理其他类型
    func onSwiperClick(_ item: SwiperModel){
        guard let data = item.data, !data.isEmpty else{
            return
        }
        switch item.type{
        case 2://推荐单曲
            guard let id = Int64(data) else{
                return
            }
            MusicApi.detail(id: id).send{
                PlayerManager.shared.prepareAndPlay([$0], favoriteId: FavoriteType.NONE)
            }
        case 3://拨打电话
            if let url = URL(string: "tel://" + data){
                UIApplication.shared.open(url)
            }
        case 4://跳转网页
            if let url = URL(string: data){
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }
}
