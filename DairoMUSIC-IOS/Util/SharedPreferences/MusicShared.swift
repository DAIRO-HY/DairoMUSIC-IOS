//
//  MusicShared.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import Foundation
import DairoUI_IOS

/// 我的歌单里的歌曲和最近播放,保存在当前账号的本地缓存里
enum MusicShared {

    /// 我的歌单里所有歌曲的缓存名
    private static let _KEY_USER_MUSIC = "user_music"

    /// 最近播放的缓存名
    private static let _KEY_LATE_MUSIC = "late_music"

    /// 最近播放最多保存的歌曲数
    private static let LATE_MAX_COUNT = 100

    /// 内存里的歌曲,歌曲很多时解析很慢
    private static var mUserMusic: [MusicModel]? = nil

    /// "我喜欢"歌单里的歌曲ID
    private static var mLikeMusicIds: Set<Int64>? = nil

    /// 我所有歌单里的歌曲,同一首歌在多个歌单里时有多条,用favoriteId区分
    static var userMusic: [MusicModel] {
        get{
            if let list = MusicShared.mUserMusic{
                return list
            }
            let list = SettingShared.accountObjectName(MusicShared._KEY_USER_MUSIC).flatMap{ LocalObjectUtil.read([MusicModel].self, $0) } ?? []
            MusicShared.mUserMusic = list
            return list
        }
        set{
            MusicShared.mUserMusic = newValue
            MusicShared.mLikeMusicIds = nil
            if let name = SettingShared.accountObjectName(MusicShared._KEY_USER_MUSIC){
                _ = LocalObjectUtil.write(newValue, name)
            }
            NotificationCenter.default.post(name: EventName.MUSIC_CHANGE, object: nil)
        }
    }

    /// 获取我的歌单里的歌曲
    static func musics(favoriteId: Int64) -> [MusicModel] {
        return MusicShared.userMusic.filter{ $0.favoriteId == favoriteId }
    }

    /// 判断是否"我喜欢"的歌曲
    static func isLike(_ musicId: Int64) -> Bool {
        if MusicShared.mLikeMusicIds == nil{
            let likeId = FavoriteShared.likeFavorite?.id
            MusicShared.mLikeMusicIds = Set(MusicShared.userMusic.filter{ $0.favoriteId == likeId }.map{ $0.id })
        }
        return MusicShared.mLikeMusicIds!.contains(musicId)
    }

    /// 后台从服务器刷新歌曲
    static func loadInBackground() {
        FavoriteApi.allMusics().hide().send{
            MusicShared.userMusic = $0
        }
    }

    /// 切换账号时清空内存里的数据
    static func clearMemory() {
        MusicShared.mUserMusic = nil
        MusicShared.mLikeMusicIds = nil
    }

    /// 添加或删除"我喜欢"
    /// - Parameter onAdded: 添加到"我喜欢"成功之后回调歌曲ID,采集平台的歌曲加入曲库之后才有ID
    static func toggleLike(_ music: MusicModel, onAdded: @escaping (_ musicId: Int64) -> Void = { _ in }) {
        guard let like = FavoriteShared.likeFavorite else{
            FavoriteShared.loadInBackground()
            Toast.show("歌单还没有加载完成,请稍后再试")
            return
        }
        if music.id != 0 && MusicShared.isLike(music.id){
            FavoriteShared.removeMusic(musicId: music.id, favoriteId: like.id)
        } else {
            FavoriteShared.addMusic(music, favoriteId: like.id, success: onAdded)
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
    static var lateMusic: [MusicModel] {
        get{
            return SettingShared.accountObjectName(MusicShared._KEY_LATE_MUSIC).flatMap{ LocalObjectUtil.read([MusicModel].self, $0) } ?? []
        }
        set{
            if let name = SettingShared.accountObjectName(MusicShared._KEY_LATE_MUSIC){
                _ = LocalObjectUtil.write(newValue, name)
            }
            NotificationCenter.default.post(name: EventName.LATE_CHANGE, object: nil)
        }
    }

    /// 添加到最近播放,已经存在时移到最前面
    static func addLate(_ music: MusicModel) {
        var list = MusicShared.lateMusic
        list.removeAll{ $0.isSameMusic(music) }
        var late = music
        late.favoriteId = nil
        list.insert(late, at: 0)
        if list.count > MusicShared.LATE_MAX_COUNT{
            list.removeLast(list.count - MusicShared.LATE_MAX_COUNT)
        }
        MusicShared.lateMusic = list
    }

    /// 清空最近播放
    static func clearLate() {
        MusicShared.lateMusic = []
    }
}
