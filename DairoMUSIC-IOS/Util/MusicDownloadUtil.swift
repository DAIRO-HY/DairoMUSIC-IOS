//
//  MusicDownloadUtil.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/08.
//

import Foundation
import DairoUI_IOS

/// 下载音质的选项
struct DownloadQuality: Hashable {

    /// 显示的名称
    let label: String

    /// 目标音质,服务器返回不超过这个音质的最高音质文件
    let bitRate: Int
}

/// 歌曲下载,下载的文件通过SDK永久保存,下载进度在缓存管理的"已下载的歌曲"里查看
enum MusicDownloadUtil {

    /// 所有下载音质
    static let QUALITIES = [
        DownloadQuality(label: "标准(128K)", bitRate: 128),
        DownloadQuality(label: "超高品质(320K)", bitRate: 320),
        DownloadQuality(label: "无损", bitRate: SettingShared.BIT_RATE_LOSSLESS)
    ]

    /// 一首歌可以下载的音质,不显示超过最高音质的选项
    /// - Parameter maxBitRate: 歌曲的最高音质,未知时显示所有选项
    static func qualities(maxBitRate: Int?) -> [DownloadQuality] {
        guard let maxBitRate, maxBitRate > 0 else{
            return MusicDownloadUtil.QUALITIES
        }
        var list = MusicDownloadUtil.QUALITIES.filter{ $0.bitRate <= maxBitRate }

        //最高音质不在选项里时(例如192K),加上最高音质
        if maxBitRate < SettingShared.BIT_RATE_LOSSLESS && !list.contains(where: { $0.bitRate == maxBitRate }){
            list.append(DownloadQuality(label: MusicModel.qualityText(maxBitRate), bitRate: maxBitRate))
        }
        return list
    }

    /// 已经下载完成的音质说明,没有下载时返回nil
    static func downloadedText(_ musicId: Int64) -> String? {
        if musicId == 0{
            return nil
        }
        let prefix = FileSdkUtil.musicKeyPrefix(musicId)
        let list = FileSdkUtil.downloads(group: FileSdkUtil.GROUP_MUSIC).filter{ $0.key.hasPrefix(prefix) }
        if list.contains(where: { $0.state == .finish }){
            return "已下载"
        }
        return list.isEmpty ? nil : "下载中"
    }

    /// 下载一首歌,还没有入库的歌曲先收藏到曲库
    static func download(_ music: MusicModel, quality: DownloadQuality) {
        MusicShared.ensureId(music){ musicId in
            MusicApi.detail(id: musicId, bitRate: quality.bitRate).send{ detail in
                guard detail.file != nil, let source = FileSource.music(detail) else{
                    Toast.show("歌曲还在处理中,请稍后再下载")
                    return
                }
                Toast.show(FileSdkUtil.download(source) ? "已加入下载列表" : "添加下载失败")
            }
        }
    }

    /// 下载歌单里的所有歌曲,还没有入库的歌曲跳过
    /// - Parameter favoriteId: 歌单ID,服务器上的歌单一次获取所有歌曲的文件,最近播放逐首获取
    static func downloadAll(_ musicList: [MusicModel], favoriteId: Int64, quality: DownloadQuality) {
        if favoriteId > 0{
            FavoriteApi.musics(id: favoriteId, bitRate: quality.bitRate).send{ list in
                MusicDownloadUtil.addAll(list, total: list.count)
            }
            return
        }
        let ids = musicList.map{ $0.id }.filter{ $0 != 0 }
        if ids.isEmpty{
            Toast.show("没有可以下载的歌曲")
            return
        }
        Loading.show()
        var details = [MusicModel]()
        var remain = ids.count
        for id in ids{
            MusicApi.detail(id: id, bitRate: quality.bitRate).hide().fail{ _ in
            }.error{ _ in
            }.finish{
                remain -= 1
                if remain == 0{
                    Loading.hide()
                    MusicDownloadUtil.addAll(details, total: musicList.count)
                }
            }.send{ detail in
                details.append(detail)
            }
        }
    }

    /// 添加下载任务,提示添加了多少首
    /// - Parameter total: 歌单里的歌曲总数,用来计算跳过的数量
    private static func addAll(_ list: [MusicModel], total: Int) {
        var count = 0
        for music in list{
            guard music.file != nil, let source = FileSource.music(music) else{
                continue
            }
            if FileSdkUtil.download(source){
                count += 1
            }
        }
        if count == 0{
            Toast.show("没有可以下载的歌曲")
        } else if count < total{
            Toast.show("已加入下载列表\(count)首,\(total - count)首暂时不能下载")
        } else {
            Toast.show("已加入下载列表\(count)首")
        }
    }
}
