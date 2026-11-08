//
//  MusicModel++.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

/// sheet(item:)等需要Identifiable,使用歌曲ID
extension MusicModel: Identifiable {}

extension MusicModel {

    /// 显示的歌名
    var nameText: String {
        return self.name ?? "未知歌曲"
    }

    /// 显示的歌手
    var artistText: String {
        return self.artist ?? "未知歌手"
    }

    /// 歌手和专辑
    var artistAlbumText: String {
        guard let album = self.album, !album.isEmpty else{
            return self.artistText
        }
        return self.artistText + " - " + album
    }

    /// 是否同一首歌,采集平台的歌曲ID为0,用采集参数判断
    func isSameMusic(_ other: MusicModel) -> Bool {
        if self.id != 0 || other.id != 0{
            return self.id == other.id
        }
        return self.collect?.platform == other.collect?.platform && self.collect?.extra == other.collect?.extra
    }

    /// 列表里使用的唯一标识,同一首歌在不同歌单里也算不同的条目
    var listId: String {
        if self.id != 0{
            return "\(self.id)-\(self.favoriteId ?? 0)"
        }
        return "\(self.collect?.platform ?? "")-\(self.collect?.extra ?? "")"
    }

    /// 获取音质的文字说明
    static func qualityText(_ bitRate: Int?) -> String {
        guard let bitRate, bitRate > 0 else{
            return "未知"
        }
        if bitRate >= SettingShared.BIT_RATE_LOSSLESS{
            return "无损"
        }
        if bitRate >= 320{
            return "超高品质(\(bitRate)K)"
        }
        if bitRate > 128{
            return "高品质(\(bitRate)K)"
        }
        return "标准(\(bitRate)K)"
    }
}
