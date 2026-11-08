//
//  FavoriteShared.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import Foundation
import DairoUI_IOS

/// 我的歌单,保存在当前账号的本地缓存里
enum FavoriteShared {

    /// 本地缓存名
    private static let _KEY_LIST = "favorite_list"

    /// 内存里的歌单,避免每次都读文件
    private static var mList: [FavoriteModel]? = nil

    /// 我的歌单,按排序
    static var list: [FavoriteModel] {
        get{
            if let list = FavoriteShared.mList{
                return list
            }
            let list = SettingShared.accountObjectName(FavoriteShared._KEY_LIST).flatMap{ LocalObjectUtil.read([FavoriteModel].self, $0) } ?? []
            FavoriteShared.mList = list
            return list
        }
        set{
            FavoriteShared.mList = newValue
            if let name = SettingShared.accountObjectName(FavoriteShared._KEY_LIST){
                _ = LocalObjectUtil.write(newValue, name)
            }
            NotificationCenter.default.post(name: EventName.FAVORITE_CHANGE, object: nil)
        }
    }

    /// "我喜欢"歌单
    static var likeFavorite: FavoriteModel? {
        return FavoriteShared.list.first{ $0.isLike }
    }

    /// 通过歌单ID获取我的歌单
    static func byId(_ id: Int64) -> FavoriteModel? {
        return FavoriteShared.list.first{ $0.id == id }
    }

    /// 后台从服务器刷新歌单
    static func loadInBackground() {
        FavoriteApi.list().hide().send{
            FavoriteShared.list = $0
        }
    }

    /// 切换账号时清空内存里的数据
    static func clearMemory() {
        FavoriteShared.mList = nil
    }

    /// 添加歌曲到歌单,采集平台的歌曲先加入曲库
    /// - Parameter success: 成功回调,参数是歌曲ID
    static func addMusic(_ music: MusicModel, favoriteId: Int64, success: @escaping (_ musicId: Int64) -> Void = { _ in }) {
        MusicShared.ensureId(music){ musicId in
            FavoriteApi.addMusic(favoriteId: favoriteId, musicId: musicId).send{
                FavoriteShared.loadInBackground()
                MusicShared.loadInBackground()
                success(musicId)
            }
        }
    }

    /// 从歌单删除歌曲
    static func removeMusic(musicId: Int64, favoriteId: Int64, success: @escaping () -> Void = {}) {
        FavoriteApi.removeMusic(favoriteId: favoriteId, musicId: musicId).send{
            FavoriteShared.loadInBackground()
            MusicShared.loadInBackground()
            success()
        }
    }
}
