//
//  MusicDownloadUtil.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/08.
//

import Foundation
import DairoFileSDK
import DairoUI_IOS

/// 下载音质的选项
struct DownloadQuality: Hashable {

    /// 显示的名称
    let label: String

    /// 目标音质,从歌曲的所有音质里选择不超过这个音质的最高音质文件
    let bitRate: Int

    /// 是否只有VIP才能下载,非VIP选择时提示需要VIP
    let vipOnly: Bool
}

/// 歌曲下载,下载的文件通过SDK永久保存,下载进度在缓存管理的"已下载的歌曲"里查看
enum MusicDownloadUtil {

    /// 非VIP选择VIP音质时的提示
    private static let VIP_TIP = "超高品质、无损音质需要VIP"

    /// 歌单全部下载时的音质选项,非VIP只能下载标准音质,其他音质显示VIP标记
    static var listQualities: [DownloadQuality] {
        let vip = ServerConfig.shared.isVipLimited
        let mark = vip ? "(VIP)" : ""
        return [
            DownloadQuality(label: "标准(128K)", bitRate: SettingStore.BIT_RATE_STANDARD, vipOnly: false),
            DownloadQuality(label: "超高品质(320K)" + mark, bitRate: 320, vipOnly: vip),
            DownloadQuality(label: "无损" + mark, bitRate: SettingStore.BIT_RATE_LOSSLESS, vipOnly: vip)
        ]
    }

    /// 一首歌可以下载的音质,列出这首歌所有音质的文件和大小,非VIP不能下载的音质显示VIP标记
    /// 还没有入库的采集平台歌曲不知道有哪些音质,显示通用的选项
    static func qualities(_ music: MusicModel) -> [DownloadQuality] {
        let files = music.downloadFiles
        if files.isEmpty{
            return MusicDownloadUtil.listQualities
        }
        let playable = Set(music.playableFiles.map{ $0.id })
        return files.map{
            let vipOnly = !playable.contains($0.id)
            return DownloadQuality(label: MusicModel.qualityText($0.bitRate) + (vipOnly ? "(VIP)" : "") + "  " + $0.size.fileSize,
                                   bitRate: $0.bitRate ?? 0, vipOnly: vipOnly)
        }
    }

    /// 下载状态:已下载、下载中,没有下载时返回nil
    static func downloadedText(_ musicId: Int64) -> String? {
        let list = MusicDownloadUtil.downloads(musicId)
        if list.contains(where: { $0.state == .finish }){
            return "已离线缓存"
        }
        return list.isEmpty ? nil : "离线缓存中"
    }

    /// 一首歌的所有下载,包括还没有下载完成的
    static func downloads(_ musicId: Int64) -> [CacheInfo] {
        if musicId == 0{
            return []
        }
        let prefix = FileSdkUtil.musicKeyPrefix(musicId)
        return FileSdkUtil.downloads(group: FileSdkUtil.GROUP_MUSIC).filter{ $0.key.hasPrefix(prefix) }
    }

    /// 下载一首歌,还没有入库的歌曲先收藏到曲库,再获取歌曲的所有音质
    static func download(_ music: MusicModel, quality: DownloadQuality) {
        if quality.vipOnly{
            Toast.show(MusicDownloadUtil.VIP_TIP)
            return
        }
        if music.id != 0 && music.hasFile{
            MusicDownloadUtil.add(music, quality: quality)
            return
        }
        MusicStore.ensureId(music){ musicId in
            MusicApi.detail(id: musicId).send{ detail in
                MusicDownloadUtil.add(detail, quality: quality)
            }
        }
    }

    /// 添加一首歌的下载任务
    private static func add(_ music: MusicModel, quality: DownloadQuality) {
        guard let file = music.file(bitRate: quality.bitRate), let source = FileSource.music(music, file: file) else{
            Toast.show("歌曲还在处理中,请稍后再离线缓存")
            return
        }
        Toast.show(FileSdkUtil.download(source) ? "已加入离线缓存列表" : "添加离线缓存失败")
    }

    /// 下载列表里的所有歌曲,每首歌选择不超过目标音质的最高音质文件,还没有入库或者还没有文件的歌曲跳过
    static func downloadAll(_ musicList: [MusicModel], quality: DownloadQuality) {
        if quality.vipOnly{
            Toast.show(MusicDownloadUtil.VIP_TIP)
            return
        }
        var count = 0
        for music in musicList where music.id != 0{
            guard let file = music.file(bitRate: quality.bitRate), let source = FileSource.music(music, file: file) else{
                continue
            }
            if FileSdkUtil.download(source){
                count += 1
            }
        }
        if count == 0{
            Toast.show("没有可以离线缓存的歌曲")
        } else if count < musicList.count{
            Toast.show("已加入离线缓存列表\(count)首,\(musicList.count - count)首暂时不能离线缓存")
        } else {
            Toast.show("已加入离线缓存列表\(count)首")
        }
    }

    /// 删除下载的文件
    static func delete(_ ids: [String]) {
        FileSdkUtil.delete(ids: ids)
    }
}
