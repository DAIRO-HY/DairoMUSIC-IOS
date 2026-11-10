//
//  PlayerManager.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import AVFoundation
import Combine
import MediaPlayer
import UIKit
import DairoUI_IOS

/**
 播放器管理,整个App共用一个播放器
 每首歌开始播放前按MusicFileResolver的规则选择文件:已经下载的、设置的音质已经缓存的直接播放本地文件,其他的在线播放(边播边缓存)
 离线模式:在线播放开始之前超时(5秒)或者失败、系统没有网络时进入离线模式,之后只播放本地有文件的歌曲,不用每首歌都等超时
 离线标记只保存在内存里;切换播放歌单、网络类型变化(WiFi、数据流量、没有网络之间切换)、用户在播放页取消时退出离线模式
 */
final class PlayerManager: ObservableObject {

    static let shared = PlayerManager()

    /// 播放信息的本地缓存名
    private static let _KEY_PLAYING_INFO = "playing_info"

    /// 播放列表
    @Published private(set) var playList = [MusicModel]()

    /// 当前播放的序号
    @Published private(set) var index = 0

    /// 播放列表的来源,参考FavoriteType
    @Published private(set) var favoriteId = FavoriteType.NONE

    /// 播放顺序
    @Published private(set) var orderType = PlayerOrderType.LIST_LOOP

    /// 是否正在播放,缓冲中也算正在播放
    @Published private(set) var isPlaying = false

    /// 是否正在加载
    @Published private(set) var isLoading = false

    /// 采集平台的歌曲还没有采集完成时,采集服务返回的进度说明,不需要等待采集时为nil
    @Published private(set) var collectMsg: String?

    /// 是否处于离线模式
    @Published private(set) var isOffline = false

    /// 进入离线模式时的网络类型,网络类型变化之后退出离线模式
    private var offlineNetwork: NetworkType?

    /// 在线播放开始之前的超时检查,开始播放或者切换歌曲时取消
    private var startTimeoutTask: Task<Void, Never>?

    /// 当前歌曲是否已经准备好开始播放,开始播放之后的失败不算断网
    private var isStarted = false

    /// 在线播放开始之前的超时时间(秒),超时之后进入离线模式
    private static let START_TIMEOUT_SECONDS: UInt64 = 5

    /// 当前播放的歌曲
    var music: MusicModel? {
        return self.playList.indices.contains(self.index) ? self.playList[self.index] : nil
    }

    private var player: AVPlayer?

    private var timeObserver: Any?

    /// 当前歌曲的监听,切换歌曲时取消
    private var cancellables = Set<AnyCancellable>()

    /// 连续播放失败的次数,超过列表里的歌曲数时停止播放
    private var errorCount = 0

    /// 是否已经设置了锁屏和控制中心的播放控制
    private var isRemoteCommandSet = false

    /// 锁屏和控制中心显示的封面
    private var artwork: MPMediaItemArtwork?

    /// 封面对应的图片地址
    private var artworkUrl: String?

    /// 歌曲还没有播放地址时,获取歌曲详情的请求
    private var detailRequest: ApiHttpBase?

    /// 等待采集完成的任务,切换歌曲时取消
    private var collectTask: Task<Void, Never>?

    /// 等待采集完成的最多次数,每秒查询一次
    private static let COLLECT_MAX_TIMES = 180

    private var progress: PlayerProgress {
        return PlayerProgress.shared
    }

    private init() {

        //来电等打断结束之后,系统允许时继续播放
        NotificationCenter.default.addObserver(self, selector: #selector(self.onInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
    }

    /*----------------------------------------------------------------------------------*/

    /// 恢复当前账号上次的播放列表,不自动播放
    func restore() {
        let info = SettingShared.accountObjectName(PlayerManager._KEY_PLAYING_INFO).flatMap{ LocalObjectUtil.read(PlayingInfo.self, $0) } ?? PlayingInfo()
        self.playList = info.playList
        self.index = info.playList.indices.contains(info.index) ? info.index : 0
        self.favoriteId = info.favoriteId
        self.orderType = info.orderType
        self.progress.currentTime = info.currentTime
        self.progress.duration = Double(self.music?.duration ?? 0) / 1000
    }

    /// 保存播放信息
    func savePlayingInfo() {
        guard let name = SettingShared.accountObjectName(PlayerManager._KEY_PLAYING_INFO) else{
            return
        }
        let info = PlayingInfo(playList: self.playList, index: self.index, favoriteId: self.favoriteId,
                               currentTime: self.progress.currentTime, orderType: self.orderType)
        _ = LocalObjectUtil.write(info, name)
    }

    /*----------------------------------------------------------------------------------*/

    /// 播放一个列表
    /// - Parameter favoriteId: 播放列表的来源,参考FavoriteType
    func prepareAndPlay(_ list: [MusicModel], index: Int = 0, favoriteId: Int64) {
        guard list.indices.contains(index) else{
            return
        }

        //切换了播放歌单时退出离线模式,在同一个歌单里点另一首歌不算
        if favoriteId != self.favoriteId || list.map({ $0.listId }) != self.playList.map({ $0.listId }){
            self.exitOffline()
        }
        self.playList = list
        self.index = index
        self.favoriteId = favoriteId
        self.errorCount = 0
        self.load(startTime: 0)
    }

    /// 播放列表里的某一首
    func playAt(_ index: Int) {
        guard self.playList.indices.contains(index) else{
            return
        }
        self.index = index
        self.errorCount = 0
        self.load(startTime: 0)
    }

    /// 播放或暂停
    func playOrPause() {
        if self.isPlaying{
            self.pause()
        } else {
            self.play()
        }
    }

    /// 继续播放,还没有加载歌曲时从上次的位置开始播放
    func play() {
        if let player = self.player, player.currentItem != nil{
            AudioSessionUtil.exclusive()
            player.play()
            return
        }
        self.load(startTime: self.progress.currentTime)
    }

    /// 暂停
    func pause() {

        //歌曲还在采集、获取详情时取消,避免准备好之后自动播放,之后点播放时重新加载
        if self.player == nil{
            self.releasePlayer()
        }
        self.player?.pause()
        self.savePlayingInfo()
    }

    /// 下一曲
    /// - Parameter auto: 是否播放结束之后自动切换,单曲循环时自动切换会重新播放当前歌曲
    func next(auto: Bool = false) {
        guard !self.playList.isEmpty else{
            return
        }
        if auto && self.orderType == .ONE_LOOP{
            self.seek(0)
            self.player?.play()
            return
        }
        self.index = self.nextIndex
        self.load(startTime: 0)
    }

    /// 上一曲
    func previous() {
        guard !self.playList.isEmpty else{
            return
        }
        self.index = (self.index - 1 + self.playList.count) % self.playList.count
        self.load(startTime: 0, direction: -1)
    }

    /// 退出离线模式,下一首开始尝试在线播放,正在播放的歌曲不中断
    func exitOffline() {
        self.isOffline = false
        self.offlineNetwork = nil
    }

    /// 下一曲的序号
    private var nextIndex: Int {
        let count = self.playList.count
        if self.orderType == .RANDOM_LOOP && count > 1{
            var index = self.index
            while index == self.index{
                index = Int.random(in: 0 ..< count)
            }
            return index
        }
        return (self.index + 1) % count
    }

    /// 下一首有视频的歌曲序号,随机播放时随机选一首,其他按列表顺序往后找,没有其他有视频的歌曲时返回nil
    var nextVideoIndex: Int? {
        let indices = self.playList.indices.filter{ $0 != self.index && self.playList[$0].videoState == 2 }
        if indices.isEmpty{
            return nil
        }
        if self.orderType == .RANDOM_LOOP{
            return indices.randomElement()
        }
        return indices.first{ $0 > self.index } ?? indices.first
    }

    /// 切换当前歌曲但不播放音乐,视频页面切换下一个视频时使用
    /// - Parameter addLate: 是否加入最近播放,定时停止时切换的歌曲还没有播放,不加入
    func selectWithoutPlaying(_ index: Int, addLate: Bool = true) {
        guard self.playList.indices.contains(index) else{
            return
        }
        self.releasePlayer()
        self.index = index
        self.progress.currentTime = 0
        self.progress.duration = Double(self.music?.duration ?? 0) / 1000
        if let music = self.music{
            self.updateArtwork(music)
            if addLate{
                MusicShared.addLate(music)
            }
        }
        self.updateNowPlaying()
        self.savePlayingInfo()
    }

    /// 跳转到指定位置
    func seek(_ seconds: Double) {
        self.progress.currentTime = seconds
        self.player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600)){ [weak self] _ in
            self?.updateNowPlaying()
        }
    }

    /// 切换到下一种播放顺序
    func switchOrderType() {
        self.orderType = self.orderType.next
        self.savePlayingInfo()
    }

    /// 从播放列表移除
    func remove(at index: Int) {
        guard self.playList.indices.contains(index) else{
            return
        }
        self.playList.remove(at: index)
        if self.playList.isEmpty{
            self.stop()
            return
        }
        if index < self.index{
            self.index -= 1
        } else if index == self.index{

            //移除的是正在播放的歌曲,接着播放下一首
            self.index = min(index, self.playList.count - 1)
            if self.isPlaying{
                self.load(startTime: 0)
            } else {
                self.releasePlayer()
                self.progress.currentTime = 0
                self.progress.duration = Double(self.music?.duration ?? 0) / 1000
            }
        }
        self.savePlayingInfo()
    }

    /// 清空播放列表,停止播放
    func stop() {
        self.releasePlayer()
        self.playList = []
        self.index = 0
        self.favoriteId = FavoriteType.NONE
        self.progress.currentTime = 0
        self.progress.duration = 0
        self.savePlayingInfo()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        AudioSessionUtil.release()
    }

    /// 采集平台的歌曲加入曲库之后,更新播放列表里的歌曲ID
    func onCollected(_ music: MusicModel, musicId: Int64) {
        var changed = false
        for i in self.playList.indices where self.playList[i].id == 0 && self.playList[i].isSameMusic(music){
            self.playList[i].id = musicId
            changed = true
        }
        if changed{
            self.savePlayingInfo()
        }
    }

    /*----------------------------------------------------------------------------------*/

    /// 加载当前歌曲并播放
    /// - Parameter startTime: 开始播放的位置(秒)
    /// - Parameter direction: 离线时当前歌曲不能播放,往哪个方向找能播放的歌曲,1:往后 -1:往前
    private func load(startTime: Double, direction: Int = 1) {
        self.releasePlayer()
        guard let music = self.music else{
            return
        }
        self.progress.currentTime = startTime
        self.progress.duration = Double(music.duration ?? 0) / 1000
        self.updateArtwork(music)
        self.updateNowPlaying()

        //本地有合适的文件(已经下载的、设置的音质已经缓存的)直接播放,不需要联网,不检查网络
        if let local = MusicFileResolver.local(music, anyQuality: false){
            self.startPlay(music, url: local.url, startTime: startTime, isOnline: false)
            return
        }
        self.checkOffline()
        if self.isOffline{
            self.loadOffline(music, startTime: startTime, direction: direction)
            return
        }
        if music.id == 0{
            self.loadCollect(music, startTime: startTime)
            return
        }
        guard let file = music.settingFile, let source = FileSource.music(music, file: file) else{

            //歌曲列表里的信息可能是采集完成之前的,重新获取歌曲详情
            self.loadDetail(music, startTime: startTime)
            return
        }
        self.startPlay(music, source: source, startTime: startTime)
    }

    /// 切换歌曲前检查离线模式:网络类型变化之后退出离线模式,系统没有网络时进入离线模式
    private func checkOffline() {
        let network = NetworkMonitor.shared.current
        if self.isOffline, let offlineNetwork = self.offlineNetwork, network != offlineNetwork, network != .unknown{
            self.exitOffline()
        }
        if !self.isOffline && network == .none{
            self.enterOffline(msg: "当前没有网络,已切换到离线模式")
        }
    }

    /// 进入离线模式,记下当时的网络类型
    private func enterOffline(msg: String) {
        if self.isOffline{
            return
        }
        self.isOffline = true
        self.offlineNetwork = NetworkMonitor.shared.current
        Toast.show(msg)
    }

    /// 离线时播放已经缓存的其他音质,没有缓存的按播放顺序找下一首本地有文件的歌曲
    private func loadOffline(_ music: MusicModel, startTime: Double, direction: Int) {
        if let local = MusicFileResolver.local(music, anyQuality: true){
            self.startPlay(music, url: local.url, startTime: startTime, isOnline: false)
            return
        }
        guard let index = self.offlinePlayableIndex(direction: direction) else{
            self.stopOffline()
            return
        }
        self.index = index
        self.load(startTime: 0, direction: direction)
    }

    /// 离线时按播放顺序找一首本地有文件的歌曲,当前这首不能播放,最多找一遍列表,找不到时返回nil
    /// 单曲循环:不切换到其他歌曲;列表循环:按方向依次往后(往前)找;随机播放:从本地有文件的歌曲里随机选
    private func offlinePlayableIndex(direction: Int) -> Int? {
        if self.orderType == .ONE_LOOP{
            return nil
        }
        let keys = FileSdkUtil.localMusicKeys()
        let isPlayable = { (music: MusicModel) -> Bool in
            if music.id != 0{
                return keys.musicIds.contains(music.id)
            }
            return FileSource.collectMusic(music).map{ keys.collectKeys.contains($0.options.cacheKey ?? "") } ?? false
        }
        let count = self.playList.count
        if self.orderType == .RANDOM_LOOP{
            return self.playList.indices.filter{ $0 != self.index && isPlayable(self.playList[$0]) }.randomElement()
        }
        for step in 1 ..< max(count, 1){
            let index = ((self.index + direction * step) % count + count) % count
            if isPlayable(self.playList[index]){
                return index
            }
        }
        return nil
    }

    /// 离线时整个列表都没有可以播放的歌曲,停止播放,停在当前歌曲
    private func stopOffline() {
        self.releasePlayer()
        self.savePlayingInfo()
        Toast.show("离线模式下没有可以播放的歌曲")
    }

    /// 采集平台的歌曲,还没有缓存时要等采集服务采集完成之后才能播放
    private func loadCollect(_ music: MusicModel, startTime: Double) {
        guard let source = FileSource.collectMusic(music), let collectUrl = music.collect?.url else{
            self.onError("歌曲没有播放地址")
            return
        }
        self.waitCollect(collectUrl, source: source, startTime: startTime)
    }

    /// 在线播放:按设置边播边缓存,或者直接在线播放
    private func startPlay(_ music: MusicModel, source: FileSource, startTime: Double) {
        guard let url = SettingShared.musicCache ? FileSdkUtil.open(source) : URL(string: source.url) else{
            self.onError("歌曲加载失败")
            return
        }
        self.startPlay(music, url: url, startTime: startTime, isOnline: true)
    }

    /// 开始播放指定地址的歌曲
    /// - Parameter isOnline: 是否在线播放,在线播放开始之前超时或者失败时进入离线模式
    private func startPlay(_ music: MusicModel, url: URL, startTime: Double, isOnline: Bool) {
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        self.observe(player, item, isOnline: isOnline, startTime: startTime)
        self.setupRemoteCommands()
        if startTime > 0{
            player.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
        }
        AudioSessionUtil.exclusive()
        player.play()
        MusicShared.addLate(music)
        self.savePlayingInfo()
        if isOnline{
            self.startTimeoutTask = Task{ @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: PlayerManager.START_TIMEOUT_SECONDS * 1_000_000_000)
                guard let self, !Task.isCancelled, self.player === player, item.status != .readyToPlay else{
                    return
                }
                self.onStartFailed(startTime: startTime)
            }
        }
    }

    /// 在线播放开始之前超时或者失败,进入离线模式,当前歌曲按离线规则重新加载
    /// 播放途中的失败不算断网
    private func onStartFailed(startTime: Double) {
        self.releasePlayer()
        self.enterOffline(msg: "网络连接超时,已切换到离线模式")
        self.load(startTime: startTime)
    }

    /// 等待采集服务采集完成,每秒查询一次进度,第一次查询时采集服务开始采集
    /// 查询地址是"播放地址/collect_info",采集完成时返回OK,没有完成时返回进度说明
    private func waitCollect(_ collectUrl: String, source: FileSource, startTime: Double) {
        guard let infoUrl = URL(string: collectUrl + "/collect_info") else{
            self.onError("歌曲没有播放地址")
            return
        }
        self.isLoading = true
        self.collectMsg = "准备采集"
        self.collectTask = Task{ @MainActor [weak self] in
            for _ in 0 ..< PlayerManager.COLLECT_MAX_TIMES{
                let data = try? await URLSession.shared.data(from: infoUrl).0
                guard let self, !Task.isCancelled else{
                    return
                }
                let msg = data.flatMap{ String(data: $0, encoding: .utf8) }
                if msg == "OK"{
                    self.collectMsg = nil
                    if let music = self.music{
                        self.startPlay(music, source: source, startTime: startTime)
                    }
                    return
                }
                self.collectMsg = msg ?? "网络连接失败,正在重试"
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled{
                    return
                }
            }
            self?.collectMsg = nil
            self?.onError("采集超时")
        }
    }

    /// 歌曲列表里的信息可能是采集完成之前的,重新获取歌曲详情之后再播放;网络连接失败时进入离线模式
    private func loadDetail(_ music: MusicModel, startTime: Double) {
        self.isLoading = true
        self.detailRequest = MusicApi.detail(id: music.id).hide().fail{ [weak self] in
            self?.isLoading = false
            self?.onError($0.msg ?? "获取歌曲信息失败")
        }.error{ [weak self] _ in
            self?.isLoading = false
            self?.onStartFailed(startTime: startTime)
        }.send{ [weak self] detail in
            guard let self, self.music?.id == detail.id else{
                return
            }
            self.isLoading = false
            if !detail.hasFile{
                self.onError("歌曲还在处理中,请稍后再试")
                return
            }
            var detail = detail
            detail.favoriteId = music.favoriteId
            self.playList[self.index] = detail
            self.load(startTime: startTime)
        }
    }

    /// 监听播放状态
    /// - Parameter isOnline: 在线播放开始之前失败时进入离线模式
    private func observe(_ player: AVPlayer, _ item: AVPlayerItem, isOnline: Bool, startTime: Double) {
        self.timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main){ [weak self] time in
            guard let self, !self.progress.isDragging, time.isNumeric else{
                return
            }
            self.progress.currentTime = time.seconds
        }

        //来电等情况系统会暂停播放,这里以播放器的实际状态为准
        player.publisher(for: \.timeControlStatus).receive(on: DispatchQueue.main).sink{ [weak self] status in
            self?.isPlaying = status != .paused
            self?.isLoading = status == .waitingToPlayAtSpecifiedRate
            self?.updateNowPlaying()
        }.store(in: &self.cancellables)
        item.publisher(for: \.status).receive(on: DispatchQueue.main).sink{ [weak self] status in
            if status == .readyToPlay{
                self?.isStarted = true
                self?.errorCount = 0
                self?.startTimeoutTask?.cancel()
            } else if status == .failed{
                if isOnline && self?.isStarted == false{
                    self?.onStartFailed(startTime: startTime)
                } else {
                    self?.onError("歌曲加载失败")
                }
            }
        }.store(in: &self.cancellables)
        item.publisher(for: \.duration).receive(on: DispatchQueue.main).sink{ [weak self] duration in
            if duration.isNumeric && duration.seconds > 0{
                self?.progress.duration = duration.seconds
                self?.updateNowPlaying()
            }
        }.store(in: &self.cancellables)
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item).receive(on: DispatchQueue.main).sink{ [weak self] _ in
            self?.onSongEnd()
        }.store(in: &self.cancellables)
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item).receive(on: DispatchQueue.main).sink{ [weak self] _ in
            self?.onError("网络连接失败")
        }.store(in: &self.cancellables)
    }

    /// 歌曲播放结束,自动播放下一曲;定时停止正在等歌曲播放结束时,切换到下一曲但不播放
    private func onSongEnd() {
        if !SleepTimer.shared.consumeSongEnd(){
            self.next(auto: true)
            return
        }
        if self.orderType == .ONE_LOOP{
            self.seek(0)
            self.pause()
        } else {
            self.selectWithoutPlaying(self.nextIndex, addLate: false)
        }
    }

    /// 播放失败时自动播放下一曲,整个列表都失败时停止
    private func onError(_ msg: String) {
        self.releasePlayer()
        self.errorCount += 1
        if self.errorCount >= self.playList.count{
            Toast.show(msg)
            return
        }
        Toast.show(msg + ",自动播放下一曲")
        self.index = self.nextIndex
        self.load(startTime: 0)
    }

    /// 释放当前歌曲的播放器
    private func releasePlayer() {
        self.isStarted = false
        self.startTimeoutTask?.cancel()
        self.startTimeoutTask = nil
        self.detailRequest?.cancel()
        self.detailRequest = nil
        self.collectTask?.cancel()
        self.collectTask = nil
        self.collectMsg = nil
        if let timeObserver = self.timeObserver{
            self.player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        self.cancellables.removeAll()
        self.player?.pause()
        self.player = nil
        self.isPlaying = false
        self.isLoading = false
    }

    /// 来电等打断结束之后,系统允许时继续播放
    @objc private func onInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: typeValue) == .ended,
              let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt,
              AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) else{
            return
        }
        DispatchQueue.main.async {
            self.player?.play()
        }
    }

    /*----------------------------------------------------------------------------------*/

    /// 设置锁屏、控制中心、耳机的播放控制
    private func setupRemoteCommands() {
        if self.isRemoteCommandSet{
            return
        }
        self.isRemoteCommandSet = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget{ [weak self] _ in
            self?.play()
            return .success
        }
        center.pauseCommand.addTarget{ [weak self] _ in
            self?.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget{ [weak self] _ in
            self?.playOrPause()
            return .success
        }
        center.nextTrackCommand.addTarget{ [weak self] _ in
            self?.next()
            return .success
        }
        center.previousTrackCommand.addTarget{ [weak self] _ in
            self?.previous()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget{ [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else{
                return .commandFailed
            }
            self?.seek(event.positionTime)
            return .success
        }
    }

    /// 更新锁屏和控制中心显示的播放信息
    private func updateNowPlaying() {
        guard let music = self.music else{
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: music.nameText,
            MPMediaItemPropertyArtist: music.artistText,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: self.progress.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: self.isPlaying ? 1.0 : 0.0
        ]
        if let album = music.album{
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if self.progress.duration > 0{
            info[MPMediaItemPropertyPlaybackDuration] = self.progress.duration
        }
        if let artwork = self.artwork{
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// 加载锁屏和控制中心显示的封面
    private func updateArtwork(_ music: MusicModel) {
        if self.artworkUrl == music.logo{
            return
        }
        self.artworkUrl = music.logo
        self.artwork = nil
        guard let logo = music.logo else{
            return
        }
        Task{ @MainActor [weak self] in
            guard let data = await FileSdkUtil.imageData(logo) else{
                return
            }
            let image = await Task.detached{
                return UIImage(data: data)
            }.value
            guard let self, let image, self.artworkUrl == logo else{
                return
            }
            self.artwork = MPMediaItemArtwork(boundsSize: image.size){ _ in image }
            self.updateNowPlaying()
        }
    }
}
