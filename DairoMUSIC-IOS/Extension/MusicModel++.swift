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

    /// 是否已经采集完成,有歌曲文件
    var hasFile: Bool {
        return !(self.files ?? []).isEmpty
    }

    /// 最高音质,还没有采集完成时为nil
    var maxBitRate: Int? {
        return self.files?.compactMap{ $0.bitRate }.max()
    }

    /// 可以在线播放、下载的文件,按音质从低到高排序
    /// 只从有播放地址的文件里选;非VIP只能用最低音质(标准音质),歌单等本地缓存的歌曲信息可能是VIP到期之前获取的,这里也要限制
    var playableFiles: [MusicFileModel] {
        let files = (self.files ?? []).filter{ $0.url != nil }.sorted{ ($0.bitRate ?? 0) < ($1.bitRate ?? 0) }
        return ServerConfig.shared.isVipLimited ? Array(files.prefix(1)) : files
    }

    /// 按目标音质选择歌曲文件:不超过目标音质的最高音质,所有文件都超过时选最低音质
    func file(bitRate target: Int) -> MusicFileModel? {
        let files = self.playableFiles
        return files.last{ ($0.bitRate ?? 0) <= target } ?? files.first
    }

    /// 按设置的播放音质选择的歌曲文件
    var settingFile: MusicFileModel? {
        return self.file(bitRate: SettingShared.bitRate)
    }

    /// 按文件ID找歌曲文件
    func file(id: Int64) -> MusicFileModel? {
        return self.files?.first{ $0.id == id }
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
