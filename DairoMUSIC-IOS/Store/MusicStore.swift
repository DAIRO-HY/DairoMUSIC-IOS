//
//  MusicStore.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import Foundation
import DairoUI_IOS

/// 我的歌单里的歌曲和最近播放,保存在当前账号的本地缓存里
enum MusicStore {

    /// 我的歌单里所有歌曲的缓存名
    private static let KEY_FAVORITE_MUSIC = "favorite_music"

    /// 最近播放的缓存名
    private static let KEY_RECENT_MUSIC = "recent_music"

    /// 最近播放最多保存的歌曲数
    private static let RECENT_MAX_COUNT = 100

    /// 内存里的歌曲,歌曲很多时解析很慢
    private static var mUserMusic: [MusicModel]? = nil

    /// "我喜欢"歌单里的歌曲ID
    private static var mLikeMusicIds: Set<Int64>? = nil

    /// 我所有歌单里的歌曲,同一首歌在多个歌单里时有多条,用favoriteId区分
    static var userMusic: [MusicModel] {
        get{
            if let list = MusicStore.mUserMusic{
                return list
            }
            let list = SettingStore.accountObjectName(MusicStore.KEY_FAVORITE_MUSIC).flatMap{ LocalObjectUtil.read([MusicModel].self, $0) } ?? []
            MusicStore.mUserMusic = list
            return list
        }
        set{
            MusicStore.mUserMusic = newValue
            MusicStore.mLikeMusicIds = nil
            if let name = SettingStore.accountObjectName(MusicStore.KEY_FAVORITE_MUSIC){
                _ = LocalObjectUtil.write(newValue, name)
            }
            NotificationCenter.default.post(name: EventName.MUSIC_CHANGE, object: nil)
        }
    }

    /// 获取我的歌单里的歌曲
    static func musics(favoriteId: Int64) -> [MusicModel] {
        return MusicStore.userMusic.filter{ $0.favoriteId == favoriteId }
    }

    /// 判断是否"我喜欢"的歌曲
    static func isLike(_ musicId: Int64) -> Bool {
        if MusicStore.mLikeMusicIds == nil{
            let likeId = FavoriteStore.likeFavorite?.id
            MusicStore.mLikeMusicIds = Set(MusicStore.userMusic.filter{ $0.favoriteId == likeId }.map{ $0.id })
        }
        return MusicStore.mLikeMusicIds!.contains(musicId)
    }

    /// 后台从服务器刷新歌曲
    static func loadInBackground() {
        FavoriteApi.allMusics().hide().send{
            MusicStore.userMusic = $0
        }
    }

    /// 切换账号时清空内存里的数据
    static func clearMemory() {
        MusicStore.mUserMusic = nil
        MusicStore.mLikeMusicIds = nil
    }

    /// 添加或删除"我喜欢"
    /// - Parameter onAdded: 添加到"我喜欢"成功之后回调歌曲ID,采集平台的歌曲加入曲库之后才有ID
    static func toggleLike(_ music: MusicModel, onAdded: @escaping (_ musicId: Int64) -> Void = { _ in }) {
        guard let like = FavoriteStore.likeFavorite else{
            FavoriteStore.loadInBackground()
            Toast.show("歌单还没有加载完成,请稍后再试")
            return
        }
        if music.id != 0 && MusicStore.isLike(music.id){
            FavoriteStore.removeMusic(musicId: music.id, favoriteId: like.id)
        } else {
            FavoriteStore.addMusic(music, favoriteId: like.id, success: onAdded)
        }
    }

    /// 确保歌曲已经在曲库里,采集平台搜索到的歌曲ID为0,需要先加入曲库
    static func ensureId(_ music: MusicModel, success: @escaping (_ musicId: Int64) -> Void) {
        if music.id != 0{
            success(music.id)
            return
        }
        guard let collect = music.collect else{
            Toast.show("歌曲信息不完整")
            return
        }
        MusicApi.collect(name: music.name ?? "", logo: music.logo, platform: collect.platform, extra: collect.extra).send{ musicId in
            PlayerManager.shared.onCollected(music, musicId: musicId)
            success(musicId)
        }
    }

    /*----------------------------------------------------------------------------------*/

    /// 最近播放
    static var recentMusic: [MusicModel] {
        get{
            return SettingStore.accountObjectName(MusicStore.KEY_RECENT_MUSIC).flatMap{ LocalObjectUtil.read([MusicModel].self, $0) } ?? []
        }
        set{
            if let name = SettingStore.accountObjectName(MusicStore.KEY_RECENT_MUSIC){
                _ = LocalObjectUtil.write(newValue, name)
            }
            NotificationCenter.default.post(name: EventName.RECENT_CHANGE, object: nil)
        }
    }

    /// 添加到最近播放,已经存在时移到最前面
    static func addRecent(_ music: MusicModel) {
        var list = MusicStore.recentMusic
        list.removeAll{ $0.isSameMusic(music) }
        var recent = music
        recent.favoriteId = nil
        list.insert(recent, at: 0)
        if list.count > MusicStore.RECENT_MAX_COUNT{
            list.removeLast(list.count - MusicStore.RECENT_MAX_COUNT)
        }
        MusicStore.recentMusic = list
    }

    /// 清空最近播放
    static func clearRecent() {
        MusicStore.recentMusic = []
    }
}
