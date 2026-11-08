//
//  VideoViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/08.
//

import AVFoundation
import Combine
import Photos
import SwiftUI
import DairoFileSDK
import DairoUI_IOS

/**
 播放页的视频
 切换到视频页面时暂停音乐,视频从头开始播放;视频播放时音乐一直暂停,离开视频页面时音乐保持暂停
 视频可能是后台单独上传的,和音乐的时间轴不一定同步,所以视频和音乐的播放进度互不影响
 视频播放结束之后自动播放播放列表里下一个有视频的歌曲
 默认在线播放,打开"视频边播边缓存"之后通过SDK播放;已经下载或缓存好的直接播放本地文件
 */
class VideoViewModel: ObservableObject {

    /// 视频接口转码、采集过程中查询的间隔(秒)
    private static let VIDEO_POLL_SECONDS: UInt64 = 3

    /// 采集平台的原画视频下载过程中查询的间隔(秒)
    private static let COLLECT_POLL_SECONDS: UInt64 = 2

    /// 等待采集平台的原画视频最多查询的次数
    private static let COLLECT_MAX_TIMES = 180

    /// 视频播放器,还没有开始播放时为nil
    @Published private(set) var player: AVPlayer?

    /// 播放进度和状态
    let state = VideoPlayerState()

    /// 是否全屏播放
    @Published private(set) var isFullScreen = false

    /// 不能播放时的提示,例如:服务器正在转码中
    @Published private(set) var tip: String?

    /// 是否正在等待服务器转码、采集
    @Published private(set) var isWaiting = false

    /// 还没有收藏的歌曲只能播放原画,需要用户确认
    @Published var showOriginalConfirm = false

    /// 当前清晰度
    @Published private(set) var quality = SettingShared.videoQuality

    /// 是否只能播放原画(还没有收藏的歌曲)
    @Published private(set) var isOriginalOnly = false

    /// 当前播放的视频是否已经下载
    @Published private(set) var isDownloaded = false

    /// 下载进度(0到100),没有下载时为nil
    @Published private(set) var downloadPercent: Int?

    /// 显示"是否保存到相册?"
    @Published var showSaveAlbumConfirm = false

    /// 当前播放的视频
    private var source: FileSource?

    /// 视频开始播放的位置(秒)
    private var startTime = 0.0

    /// 当前视频对应的歌曲
    private var music: MusicModel?

    /// 还没有收藏的歌曲,用户已经确认播放原画
    private var isOriginalConfirmed = false

    /// 转码、采集过程中查询的任务
    private var pollTask: Task<Void, Never>?

    /// 获取视频信息的请求
    private var request: ApiHttpBase?

    /// 下载任务,离开页面时只取消回调,下载会继续
    private var downloadTask: FetchTask?

    private var cancellables = Set<AnyCancellable>()

    init() {

        //服务器配置变化时刷新下载按钮
        ServerConfig.shared.objectWillChange.receive(on: DispatchQueue.main).sink{ [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &self.configCancellables)
    }

    /// 监听服务器配置,不能放在cancellables里,停止播放时会清空cancellables
    private var configCancellables = Set<AnyCancellable>()

    /// 是否允许下载视频,服务器的设置,不允许时不显示下载按钮
    var allowDownload: Bool {
        return ServerConfig.shared.allowDownloadVideo
    }

    /// 是否允许保存到相册,服务器的设置
    var allowSaveAlbum: Bool {
        return ServerConfig.shared.allowSaveAlbum
    }

    /// 是否可以点击下载按钮,已经下载时只有允许保存到相册才可以再点
    var canDownload: Bool {
        return self.source != nil && self.downloadPercent == nil && (!self.isDownloaded || self.allowSaveAlbum)
    }

    /*----------------------------------------------------------------------------------*/

    /// 进入视频页面,从头播放当前歌曲的视频
    func enter() {
        self.music = PlayerManager.shared.music
        self.startTime = 0
        self.isOriginalConfirmed = false
        self.load()
    }

    /// 离开视频页面,停止播放
    func leave() {
        self.stop()
    }

    /// 是否正在显示这首歌曲的视频
    func isShowing(_ music: MusicModel?) -> Bool {
        guard let music, let current = self.music else{
            return false
        }
        return current.isSameMusic(music)
    }

    /// 暂停视频:App进入后台时视频不允许后台播放,音乐开始播放时视频暂停
    func pause() {
        self.player?.pause()
    }

    /// 全屏播放,iPhone上横向的视频切换到横屏
    func enterFullScreen() {
        self.isFullScreen = true
        OrientationUtil.rotate(landscape: !self.state.isPortraitVideo)
    }

    /// 退出全屏,iPhone上回到竖屏
    func exitFullScreen() {
        if !self.isFullScreen{
            return
        }
        self.isFullScreen = false
        OrientationUtil.rotate(landscape: false)
    }

    /// 切换清晰度,从当前位置继续播放
    func onQualityChange(_ quality: Int) {
        if quality == self.quality{
            return
        }
        self.quality = quality
        SettingShared.videoQuality = quality
        self.reloadKeepingTime()
    }

    /// 用户确认播放原画
    func onOriginalConfirm() {
        self.isOriginalConfirmed = true
        self.load()
    }

    /// 切换到下一个有视频的歌曲
    func onNextClick() {
        if !self.playNext(){
            Toast.show("播放列表里没有其他有视频的歌曲")
        }
    }

    /// 播放播放列表里下一个有视频的歌曲,没有时返回false
    @discardableResult
    private func playNext() -> Bool {
        guard let index = PlayerManager.shared.nextVideoIndex else{
            return false
        }
        PlayerManager.shared.selectWithoutPlaying(index)
        self.enter()
        return true
    }

    /// 重新加载当前歌曲的视频,从当前位置继续播放
    private func reloadKeepingTime() {
        if let time = self.player?.currentTime().seconds, time.isFinite{
            self.startTime = time
        }
        self.load()
    }

    /*----------------------------------------------------------------------------------*/

    /// 加载视频
    private func load() {
        self.stop()
        guard let music = self.music else{
            self.tip = "没有正在播放的歌曲"
            return
        }
        if music.id == 0{
            self.loadCollect(music)
            return
        }
        self.isOriginalOnly = false
        if music.videoState == 3 || music.videoState == 4{
            self.tip = "该歌曲没有视频"
            return
        }
        self.requestVideo(music)
    }

    /// 还没有收藏的歌曲,播放采集平台的原画视频
    private func loadCollect(_ music: MusicModel) {
        self.isOriginalOnly = true
        guard let source = FileSource.collectVideo(music), let infoUrl = music.collect?.videoInfoUrl.flatMap({ URL(string: $0) }) else{
            self.tip = "该歌曲没有视频"
            return
        }

        //已经缓存过的不需要再确认,当前清晰度已经是原画时也不需要确认
        if FileSdkUtil.cachedPath(source) != nil{
            self.play(source)
            return
        }
        if !self.isOriginalConfirmed && self.quality != SettingShared.VIDEO_QUALITY_ORIGINAL{
            self.tip = "当前音乐未收藏,只能播放原画版"
            self.showOriginalConfirm = true
            return
        }

        //查询采集平台的视频是否可以播放,第一次请求时开始下载
        self.isWaiting = true
        self.tip = "正在准备视频"
        self.pollTask = Task{ @MainActor [weak self] in
            for _ in 0 ..< VideoViewModel.COLLECT_MAX_TIMES{
                let data = try? await URLSession.shared.data(from: infoUrl).0
                guard let self, !Task.isCancelled else{
                    return
                }
                let msg = data.flatMap{ String(data: $0, encoding: .utf8) } ?? "网络连接失败,正在重试"
                if msg == "OK"{
                    self.play(source)
                    return
                }
                self.tip = msg
                if msg.hasPrefix("采集失败"){
                    self.isWaiting = false
                    return
                }
                try? await Task.sleep(nanoseconds: VideoViewModel.COLLECT_POLL_SECONDS * 1_000_000_000)
                if Task.isCancelled{
                    return
                }
            }
            self?.isWaiting = false
            self?.tip = "视频准备超时,请稍后再试"
        }
    }

    /// 获取歌曲的视频,没有采集时服务器会开始采集,采集和转码过程中定时查询
    private func requestVideo(_ music: MusicModel) {
        self.isWaiting = true
        if self.tip == nil{
            self.tip = "正在获取视频"
        }
        self.request = MusicApi.video(id: music.id).hide().fail{ [weak self] in
            self?.isWaiting = false
            self?.tip = $0.msg ?? "获取视频失败"
        }.error{ [weak self] in
            self?.isWaiting = false
            self?.tip = $0
        }.send{ [weak self] video in
            guard let self, self.music?.id == music.id else{
                return
            }
            self.onVideo(video, music: music)
        }
    }

    /// 处理视频信息
    private func onVideo(_ video: VideoModel, music: MusicModel) {
        switch video.state{
        case 2://有视频
            let file = self.quality == SettingShared.VIDEO_QUALITY_ORIGINAL ? video.original : video.smooth
            guard let file else{
                self.waitAndRetry(music, tip: "服务器正在转码中")
                return
            }
            switch file.state{
            case 1:
                guard let source = FileSource.video(file, music: music) else{
                    self.showTip("视频地址不正确")
                    return
                }
                self.play(source)
            case 2:
                self.showTip("视频转码失败")
            default:
                self.waitAndRetry(music, tip: "服务器正在转码中")
            }
        case 3, 4:
            self.showTip("该歌曲没有视频")
        case 5:
            self.showTip("视频采集失败")
        default://未采集、采集中,请求接口时服务器已经开始采集
            self.waitAndRetry(music, tip: "服务器正在采集视频")
        }
    }

    /// 显示提示,不再等待
    private func showTip(_ tip: String) {
        self.isWaiting = false
        self.tip = tip
    }

    /// 显示提示,一段时间之后重新获取视频信息
    private func waitAndRetry(_ music: MusicModel, tip: String) {
        self.isWaiting = true
        self.tip = tip
        self.pollTask = Task{ @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: VideoViewModel.VIDEO_POLL_SECONDS * 1_000_000_000)
            guard let self, !Task.isCancelled, self.music?.id == music.id else{
                return
            }
            self.requestVideo(music)
        }
    }

    /*----------------------------------------------------------------------------------*/

    /// 播放视频,已经下载或缓存好的直接播放本地文件,其他的按设置在线播放或者边播边缓存
    private func play(_ source: FileSource) {
        let url: URL?
        if let path = FileSdkUtil.cachedPath(source){
            url = URL(fileURLWithPath: path)
        } else if SettingShared.videoCache{
            url = FileSdkUtil.open(source)
        } else {
            url = URL(string: source.url)
        }
        guard let url else{
            self.showTip("视频地址不正确")
            return
        }
        self.source = source
        self.isDownloaded = FileSdkUtil.isDownloaded(source)
        self.isWaiting = false
        self.tip = nil
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        item.publisher(for: \.status).receive(on: DispatchQueue.main).sink{ [weak self] status in
            if status == .failed{
                self?.exitFullScreen()
                self?.player = nil
                self?.showTip("视频加载失败,请检查网络")
            }
        }.store(in: &self.cancellables)
        if self.startTime > 0{
            player.seek(to: CMTime(seconds: self.startTime, preferredTimescale: 600))
        }
        self.state.attach(player)

        //视频播放时暂停音乐
        self.state.$isPlaying.filter{ $0 }.sink{ _ in
            if PlayerManager.shared.isPlaying{
                PlayerManager.shared.pause()
            }
        }.store(in: &self.cancellables)

        //播放结束之后自动播放下一个视频,没有下一个时停在结束的画面
        self.state.$isEnded.filter{ $0 }.receive(on: DispatchQueue.main).sink{ [weak self] _ in
            self?.playNext()
        }.store(in: &self.cancellables)
        AudioSessionUtil.exclusive()
        player.play()
        self.player = player
    }

    /// 停止播放和查询
    private func stop() {
        self.pollTask?.cancel()
        self.pollTask = nil
        self.request?.cancel()
        self.request = nil
        self.cancellables.removeAll()
        self.exitFullScreen()
        self.state.detach()
        self.player?.pause()
        self.player = nil
        self.source = nil
        self.tip = nil
        self.isWaiting = false
        self.downloadTask?.cancel()
        self.downloadTask = nil
        self.downloadPercent = nil
    }

    /*----------------------------------------------------------------------------------*/

    /// 下载按钮点击事件,允许保存到相册时先询问
    func onDownloadClick() {
        if self.allowSaveAlbum{
            self.showSaveAlbumConfirm = true
            return
        }
        self.download(saveAlbum: false)
    }

    /// 下载当前清晰度的视频,已经缓存好的直接转为下载,不会重新下载
    /// - Parameter saveAlbum: 下载完成之后是否保存到相册
    func download(saveAlbum: Bool) {
        guard let source = self.source else{
            return
        }
        self.downloadPercent = 0
        self.downloadTask = FileSdkUtil.fetchSave(source, progress: { [weak self] in
            self?.downloadPercent = $0
        }, finish: { [weak self] path, error in
            self?.downloadPercent = nil
            guard let path else{
                Toast.show("下载失败:" + (error ?? ""))
                return
            }
            self?.isDownloaded = true
            if saveAlbum{
                VideoViewModel.saveToAlbum(path)
            } else {
                Toast.show("下载完成")
            }
        })
    }

    /// 保存到相册,只需要添加照片的权限
    private static func saveToAlbum(_ path: String) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly){ status in
            guard status == .authorized || status == .limited else{
                DispatchQueue.main.async {
                    Toast.show("没有相册权限,请在系统设置里允许添加照片")
                }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: path))
            }){ success, error in
                DispatchQueue.main.async {
                    Toast.show(success ? "已保存到相册" : "保存到相册失败:" + (error?.localizedDescription ?? ""))
                }
            }
        }
    }
}
