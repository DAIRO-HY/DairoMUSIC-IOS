//
//  FileSdkUtil.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import Foundation
import DairoFileSDK

/// <summary>
/// 文件下载缓存SDK,整个App共用一个实例
/// </summary>
enum FileSdkUtil {

    ///SDK数据目录名
    private static let ROOT_FOLDER = "dairo-file-sdk"

    ///歌曲缓存分组
    static let GROUP_MUSIC = "music"

    ///图片缓存分组
    static let GROUP_IMAGE = "image"

    ///视频缓存分组
    static let GROUP_VIDEO = "video"

    ///SDK实例的创建结果,创建失败时,在使用的地方抛出错误
    private static let result = Result { try FileSdkUtil.create() }

    /**
     获取SDK实例
     */
    static func get() throws -> FileSdk {
        return try FileSdkUtil.result.get()
    }

    /**
     App回到前台时调用,本机HTTP服务失效时会重启,之前拿到的本机地址依然有效
     */
    static func checkServer() {
        do {
            _ = try FileSdkUtil.get().checkServer()
        } catch {
            print("检查SDK本机HTTP服务失败:\(error)")
        }
    }

    /**
     App进入后台时调用
     */
    static func flush() {
        do {
            try FileSdkUtil.get().flush()
        } catch {
            print("SDK保存数据失败:\(error)")
        }
    }

    /**
     获取已经缓存的文件路径,没有缓存时返回nil
     */
    static func cachedPath(_ source: FileSource) -> String? {
        return try? FileSdkUtil.get().cachedPath(url: source.url, options: source.options)
    }

    /**
     获取无状态的本机地址,适合列表里大量的图片,连接断开时SDK会自动取消下载
     */
    static func localUrl(_ source: FileSource) -> URL? {
        guard let url = try? FileSdkUtil.get().localUrl(url: source.url, options: source.options) else{
            return nil
        }
        return URL(string: url)
    }

    /**
     获取给播放器使用的本机地址,支持边下边播
     */
    static func open(_ source: FileSource) -> URL? {
        guard let url = try? FileSdkUtil.get().open(url: source.url, options: source.options) else{
            return nil
        }
        return URL(string: url)
    }

    /**
     是否已经永久下载完成
     */
    static func isDownloaded(_ source: FileSource) -> Bool {
        guard let sdk = try? FileSdkUtil.get(), let id = try? sdk.cacheId(url: source.url, options: source.options),
              let info = try? sdk.get(id: id) else{
            return false
        }
        return info.mode == .save && info.state == .finish
    }

    /**
     下载并永久保存,已经缓存完成时直接转为永久保存,不会重新下载
     回调都在主线程,取消之后不会再回调,但下载任务会继续
     - Parameter progress: 下载进度(0到100)
     - Parameter finish: 下载结束,成功时返回文件路径,失败时返回错误信息
     */
    static func fetchSave(_ source: FileSource,
                          progress: @escaping (_ percent: Int) -> Void,
                          finish: @escaping (_ path: String?, _ error: String?) -> Void) -> FetchTask? {
        do {
            var options = source.options
            options.cache = .save
            let listener = FileSdkFetchListener(progress: progress, finish: finish)
            return try FileSdkUtil.get().fetch(url: source.url, options: options, listener: listener)
        } catch {
            finish(nil, error.localizedDescription)
            return nil
        }
    }

    /**
     各分组的统计
     - Parameter mode: cache:缓存 save:永久下载
     */
    static func stats(mode: CacheMode) -> [GroupStats] {
        return (try? FileSdkUtil.get().stats(mode: mode)) ?? []
    }

    /*----------------------------------------------------------------------------------*/

    /**
     歌曲文件缓存key的前缀,后面加文件ID;同一首歌不同音质的文件前缀相同
     */
    static func musicKeyPrefix(_ musicId: Int64) -> String {
        return "/music/\(musicId)/file/"
    }

    /**
     添加永久保存的后台下载任务,已经缓存完成时直接转为永久保存,不会重新下载
     */
    @discardableResult
    static func download(_ source: FileSource) -> Bool {
        var options = source.options
        options.cache = .save
        do {
            _ = try FileSdkUtil.get().download(url: source.url, options: options)
            return true
        } catch {
            print("添加下载任务失败:\(error)")
            return false
        }
    }

    /**
     当前服务器永久下载的文件,包括还没有下载完成的,最近添加的在前面
     - Parameter group: 分组
     */
    static func downloads(group: String) -> [CacheInfo] {
        guard let sdk = try? FileSdkUtil.get() else{
            return []
        }
        let serverId = SettingShared.serverId
        var result = [CacheInfo]()
        var offset: UInt64 = 0
        let limit: UInt64 = 500
        while true{
            guard let page = try? sdk.list(query: CacheQuery(group: group, mode: .save, offset: offset, limit: limit)) else{
                break
            }
            result.append(contentsOf: page.filter{ $0.namespace == serverId })
            if UInt64(page.count) < limit{
                break
            }
            offset += limit
        }
        return result
    }

    /**
     已经下载完成的歌曲文件路径,不管是哪种音质,有多个时使用音质最高的(文件最大的)
     */
    static func downloadedMusicPath(_ musicId: Int64) -> String? {
        let prefix = FileSdkUtil.musicKeyPrefix(musicId)
        return FileSdkUtil.downloads(group: FileSdkUtil.GROUP_MUSIC)
            .filter{ $0.key.hasPrefix(prefix) && $0.state == .finish && $0.path != nil }
            .max{ ($0.size ?? 0) < ($1.size ?? 0) }?.path
    }

    /**
     删除缓存或下载的文件,正在下载的会先停止
     */
    static func delete(ids: [String]) {
        do {
            try FileSdkUtil.get().delete(ids: ids)
        } catch {
            print("删除下载失败:\(error)")
        }
    }

    /**
     暂停下载
     */
    static func pause(ids: [String]) {
        _ = try? FileSdkUtil.get().pause(ids: ids)
    }

    /**
     继续下载,下载失败的重新下载
     */
    static func resume(ids: [String]) {
        _ = try? FileSdkUtil.get().resume(ids: ids)
    }

    /**
     清理缓存,不包括正在使用的缓存,会读写文件,不能在主线程调用
     - Parameter group: 缓存分组,为nil时清理所有分组
     */
    static func clearCache(group: String?) {
        _ = try? FileSdkUtil.get().clearCache(group: group, beforeAccess: nil)
    }

    /**
     设置缓存容量上限,超过之后自动清理最久没有使用的缓存
     - Parameter mb: 容量上限(MB),0表示不限制
     */
    static func setMaxCacheSize(_ mb: Int) {
        try? FileSdkUtil.get().setMaxCacheSize(size: UInt64(mb) * 1024 * 1024)
    }

    /**
     创建SDK实例,数据目录不能用Caches,否则会被系统清理
     */
    private static func create() throws -> FileSdk {
        var root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(FileSdkUtil.ROOT_FOLDER)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try root.setResourceValues(values)
        let sdk = try FileSdk(config: SdkConfig(rootDir: root.path))

        //SDK不负责保存设置,启动时再设置一次
        if SettingShared.fileSdkMaxCachingCount > 0{
            sdk.setMaxCachingCount(count: UInt32(SettingShared.fileSdkMaxCachingCount))
        }
        if let days = SettingShared.fileSdkCacheExpireDays{
            sdk.setCacheExpireDays(days: UInt32(days))
        }
        if SettingShared.fileSdkMaxCacheSize > 0{
            sdk.setMaxCacheSize(size: UInt64(SettingShared.fileSdkMaxCacheSize) * 1024 * 1024)
        }
        return sdk
    }
}

/// 要通过SDK访问的文件,歌曲和图片都是公开地址,不需要登录票据
struct FileSource {

    /// 下载地址
    let url: String

    /// SDK访问参数
    let options: Options

    /// 缓存文件的扩展名,未知时为空,此时缓存文件没有扩展名,播放器不能直接播放
    let ext: String

    /// 歌曲文件,没有采集完成时使用采集平台的播放地址,都没有时返回nil
    static func music(_ music: MusicModel) -> FileSource? {
        let name = music.name ?? "\(music.id)"
        if let file = music.file, let url = file.url, !url.isEmpty{

            //用歌曲ID和文件ID作为缓存key,DFS换了地址或者重新生成公开路径之后缓存依然有效,播放时可以按歌曲ID找到已经下载的文件;有MD5时下载完成后校验
            //文件名带上歌手和音质,下载列表里显示
            let displayName = "\(music.nameText) - \(music.artistText) [\(MusicModel.qualityText(file.bitRate))].\(file.format)"
            return FileSource(url: url, options: Options(group: FileSdkUtil.GROUP_MUSIC, namespace: SettingShared.serverId,
                                                         cacheKey: FileSdkUtil.musicKeyPrefix(music.id) + "\(file.id)", name: displayName,
                                                         md5: file.md5, thumb: music.logo),
                              ext: file.format)
        }
        if let collect = music.collect, let url = collect.url, !url.isEmpty{

            //采集平台的播放地址可能每次都不一样,用采集参数作为缓存key;扩展名从地址里获取,获取不到时为空
            let ext = URL(string: url)?.pathExtension.lowercased() ?? ""
            return FileSource(url: url, options: Options(group: FileSdkUtil.GROUP_MUSIC, namespace: SettingShared.serverId,
                                                         cacheKey: "/collect/\(collect.platform)/\(collect.extra)",
                                                         name: ext.isEmpty ? name : "\(name).\(ext)"), ext: ext)
        }
        return nil
    }

    /// 歌曲视频,用文件ID作为缓存key,换了地址之后缓存和下载依然有效
    static func video(_ file: VideoFileModel, music: MusicModel) -> FileSource? {
        guard let url = file.url, !url.isEmpty else{
            return nil
        }
        let quality = file.quality == SettingShared.VIDEO_QUALITY_ORIGINAL ? "原画" : "流畅"
        return FileSource(url: url, options: Options(group: FileSdkUtil.GROUP_VIDEO, namespace: SettingShared.serverId,
                                                     cacheKey: "/video/file/\(file.id)", name: "\(music.nameText) - \(music.artistText) [\(quality)].mp4",
                                                     md5: file.md5, thumb: music.logo),
                          ext: "mp4")
    }

    /// 采集平台的原画视频,还没有入库的歌曲使用,用采集参数作为缓存key
    static func collectVideo(_ music: MusicModel) -> FileSource? {
        guard let collect = music.collect, let url = collect.videoUrl, !url.isEmpty else{
            return nil
        }
        return FileSource(url: url, options: Options(group: FileSdkUtil.GROUP_VIDEO, namespace: SettingShared.serverId,
                                                     cacheKey: "/collect-video/\(collect.platform)/\(collect.extra)",
                                                     name: "\(music.nameText) - \(music.artistText) [原画].mp4", thumb: music.logo), ext: "mp4")
    }

    /// 图片,采集平台的图片地址可能用参数区分,缓存key包含参数部分
    static func image(_ url: String) -> FileSource {
        return FileSource(url: url, options: Options(group: FileSdkUtil.GROUP_IMAGE, keyMode: .pathAndQuery,
                                                     priority: 1), ext: "")
    }
}

/// 下载回调,转发到主线程
private final class FileSdkFetchListener: FetchListener, @unchecked Sendable {
    private let progress: (_ percent: Int) -> Void
    private let finish: (_ path: String?, _ error: String?) -> Void

    init(progress: @escaping (_ percent: Int) -> Void, finish: @escaping (_ path: String?, _ error: String?) -> Void) {
        self.progress = progress
        self.finish = finish
    }

    func onProgress(size: UInt64?, downloaded: UInt64) {
        guard let size, size > 0 else{
            return
        }
        let percent = Int(Double(downloaded) / Double(size) * 100)
        DispatchQueue.main.async {
            self.progress(percent)
        }
    }

    func onSuccess(path: String) {
        DispatchQueue.main.async {
            self.finish(path, nil)
        }
    }

    func onError(error: SdkError) {
        if case .Cancelled = error{
            return
        }
        DispatchQueue.main.async {
            self.finish(nil, "\(error)")
        }
    }
}
