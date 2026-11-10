//
//  MusicFileResolver.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/10.
//

import Foundation
import DairoFileSDK

/// 本地可以直接播放的歌曲文件
struct LocalMusicFile {

    /// 播放地址,本地文件或者SDK的本机地址(没有扩展名的缓存文件播放器识别不了格式,交给SDK)
    let url: URL

    /// 对应的音质文件,采集平台的歌曲为nil
    let file: MusicFileModel?

    /// 是否是永久下载的文件
    let isDownloaded: Bool
}

/**
 选择要播放的歌曲文件,切换歌曲和歌曲信息页使用同样的规则:
 1. 已经下载的歌曲,使用下载的文件,下载了多种音质时使用音质最好的
 2. 没有下载的歌曲,按设置的播放音质从所有音质的文件里选择,已经缓存好的直接播放缓存文件
 3. 离线时,设置的音质没有缓存的,使用已经缓存好的其他音质
 */
enum MusicFileResolver {

    /// 已经下载的音质最好的文件
    static func downloaded(_ music: MusicModel) -> LocalMusicFile? {
        if music.id == 0{
            return nil
        }
        return MusicFileResolver.best(music, FileSdkUtil.finishedMusics(music.id, onlyDownloaded: true))
    }

    /// 本地可以直接播放的文件,不需要联网
    /// - Parameter anyQuality: 设置的音质没有缓存时,是否使用已经缓存的其他音质(离线时)
    static func local(_ music: MusicModel, anyQuality: Bool) -> LocalMusicFile? {
        if music.id == 0{
            return MusicFileResolver.collectCached(music)
        }
        let finished = FileSdkUtil.finishedMusics(music.id, onlyDownloaded: false)
        if finished.isEmpty{
            return nil
        }
        if let downloaded = MusicFileResolver.best(music, finished.filter{ $0.mode == .save }){
            return downloaded
        }
        if let file = music.settingFile, let info = finished.first(where: { FileSdkUtil.musicFileId($0.key) == file.id }), let path = info.path{
            return LocalMusicFile(url: URL(fileURLWithPath: path), file: file, isDownloaded: false)
        }
        return anyQuality ? MusicFileResolver.best(music, finished) : nil
    }

    /// 歌曲信息页显示的文件:已经下载的显示下载的音质最好的文件,没有下载时显示按设置的音质选择的文件
    static func displayFile(_ music: MusicModel) -> (file: MusicFileModel?, isDownloaded: Bool) {
        if let downloaded = MusicFileResolver.downloaded(music), let file = downloaded.file{
            return (file, true)
        }
        return (music.settingFile, false)
    }

    /// 音质最好的文件,按比特率比较,文件信息里没有的(歌曲信息过期了)按文件大小比较
    private static func best(_ music: MusicModel, _ list: [CacheInfo]) -> LocalMusicFile? {
        let candidates = list.compactMap{ info -> (info: CacheInfo, file: MusicFileModel?, path: String)? in
            guard let path = info.path else{
                return nil
            }
            return (info, FileSdkUtil.musicFileId(info.key).flatMap{ music.file(id: $0) }, path)
        }
        let best = candidates.max{ a, b in
            let rateA = a.file?.bitRate ?? 0
            let rateB = b.file?.bitRate ?? 0
            return rateA != rateB ? rateA < rateB : (a.info.size ?? 0) < (b.info.size ?? 0)
        }
        guard let best else{
            return nil
        }
        return LocalMusicFile(url: URL(fileURLWithPath: best.path), file: best.file, isDownloaded: best.info.mode == .save)
    }

    /// 采集平台的歌曲已经缓存好的文件
    private static func collectCached(_ music: MusicModel) -> LocalMusicFile? {
        guard let source = FileSource.collectMusic(music), let path = FileSdkUtil.cachedPath(source) else{
            return nil
        }
        if source.ext.isEmpty{
            return FileSdkUtil.open(source).map{ LocalMusicFile(url: $0, file: nil, isDownloaded: false) }
        }
        return LocalMusicFile(url: URL(fileURLWithPath: path), file: nil, isDownloaded: false)
    }
}
