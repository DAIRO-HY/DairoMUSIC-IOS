//
//  VideoPlayerView.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/08.
//

import AVFoundation
import Combine
import SwiftUI

/// 视频播放状态,播放进度变化时只刷新播放控件
class VideoPlayerState: ObservableObject {

    /// 当前播放位置(秒)
    @Published var currentTime = 0.0

    /// 视频总时长(秒)
    @Published private(set) var duration = 0.0

    /// 是否正在拖动进度条,拖动时不更新播放位置
    @Published var isDragging = false

    /// 是否正在播放(包括缓冲中)
    @Published private(set) var isPlaying = false

    /// 是否正在缓冲
    @Published private(set) var isBuffering = false

    /// 是否已经播放结束
    @Published private(set) var isEnded = false

    /// 是否是竖向的视频,全屏时竖向的视频不切换到横屏
    @Published private(set) var isPortraitVideo = false

    /// 视频画面的尺寸,还没有加载时为0
    @Published private(set) var videoSize = CGSize.zero

    /// 视频帧率,还没有加载时为0
    @Published private(set) var frameRate: Float = 0

    /// 当前的播放器
    private var player: AVPlayer?

    /// 播放进度的监听
    private var timeObserver: Any?

    private var cancellables = Set<AnyCancellable>()

    /// 绑定播放器,监听播放进度和状态
    func attach(_ player: AVPlayer) {
        self.detach()
        self.player = player
        self.timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main){ [weak self] time in
            guard let self, !self.isDragging else{
                return
            }
            self.currentTime = time.seconds.isFinite ? time.seconds : 0
        }
        player.publisher(for: \.timeControlStatus).receive(on: DispatchQueue.main).sink{ [weak self] status in
            self?.isPlaying = status != .paused
            self?.isBuffering = status == .waitingToPlayAtSpecifiedRate
            if status == .playing{
                self?.isEnded = false
            }
        }.store(in: &self.cancellables)
        guard let item = player.currentItem else{
            return
        }
        item.publisher(for: \.duration).receive(on: DispatchQueue.main).sink{ [weak self] duration in
            self?.duration = duration.seconds.isFinite ? duration.seconds : 0
        }.store(in: &self.cancellables)
        item.publisher(for: \.presentationSize).receive(on: DispatchQueue.main).sink{ [weak self] size in
            self?.isPortraitVideo = size.height > size.width
            self?.videoSize = size
        }.store(in: &self.cancellables)

        //帧率从视频轨道读取,在线视频需要等文件头加载完成
        Task{ @MainActor [weak self] in
            let tracks = try? await item.asset.loadTracks(withMediaType: .video)
            guard let rate = try? await tracks?.first?.load(.nominalFrameRate), let self, self.player?.currentItem === item else{
                return
            }
            self.frameRate = rate
        }
        NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: item).receive(on: DispatchQueue.main).sink{ [weak self] _ in
            self?.isEnded = true
        }.store(in: &self.cancellables)
    }

    /// 解除绑定的播放器
    func detach() {
        if let timeObserver = self.timeObserver{
            self.player?.removeTimeObserver(timeObserver)
        }
        self.timeObserver = nil
        self.cancellables.removeAll()
        self.player = nil
        self.currentTime = 0
        self.duration = 0
        self.isDragging = false
        self.isPlaying = false
        self.isBuffering = false
        self.isEnded = false
        self.isPortraitVideo = false
        self.videoSize = .zero
        self.frameRate = 0
    }

    /// 分辨率和帧率,例如:1080P 30FPS、4K 60FPS,还没有加载时为nil
    var formatText: String? {
        guard let resolution = VideoPlayerState.resolutionText(self.videoSize) else{
            return nil
        }
        if self.frameRate <= 0{
            return resolution
        }
        return resolution + " \(Int(self.frameRate.rounded()))FPS"
    }

    /// 按长边判断分辨率,竖向和宽银幕的视频也能正确显示
    static func resolutionText(_ size: CGSize) -> String? {
        let long = max(size.width, size.height)
        let short = min(size.width, size.height)
        if long <= 0{
            return nil
        }
        if long >= 3840{
            return "4K"
        }
        if long >= 2560{
            return "2K"
        }
        if long >= 1920{
            return "1080P"
        }
        if long >= 1280{
            return "720P"
        }
        if long >= 854{
            return "480P"
        }
        return "\(Int(short))P"
    }

    /// 播放或暂停,播放结束之后从头开始播放
    func playOrPause() {
        guard let player = self.player else{
            return
        }
        if self.isPlaying{
            player.pause()
            return
        }
        if self.isEnded{
            player.seek(to: .zero)
        }
        player.play()
    }

    /// 跳到指定位置(秒),跳转完成之前不更新进度,避免进度条跳回原来的位置
    func seek(_ time: Double) {
        guard let player = self.player else{
            self.isDragging = false
            return
        }
        self.isDragging = true
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero){ [weak self] _ in
            DispatchQueue.main.async {
                self?.isDragging = false
            }
        }
    }
}

/// 视频播放控件:画面、播放暂停按钮、进度条和全屏按钮,点击画面显示或隐藏控制按钮
struct VideoPlayerView: View {

    /// 播放时控制按钮自动隐藏的时间(秒),默认3秒;UI测试时通过启动参数VIDEO_CONTROLS_HIDE_SECONDS加长,避免点击之前按钮就隐藏了
    private static let HIDE_CONTROLS_SECONDS: UInt64 = {
        let seconds = UserDefaults.standard.integer(forKey: "VIDEO_CONTROLS_HIDE_SECONDS")
        return seconds > 0 ? UInt64(seconds) : 3
    }()

    let player: AVPlayer

    @ObservedObject var state: VideoPlayerState

    /// 是否是全屏显示
    let isFullScreen: Bool

    /// 全屏、退出全屏按钮点击事件
    let onFullScreenClick: () -> Void

    /// 是否显示控制按钮
    @State private var showControls = true

    /// 自动隐藏控制按钮的任务
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack{
            Color.black
            VideoLayerView(player: self.player)
            if self.showControls || !self.state.isPlaying{
                self.controls.transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)){
                self.showControls.toggle()
            }
            self.scheduleHide()
        }
        .onAppear(perform: self.scheduleHide)
        .onDisappear{
            self.hideTask?.cancel()
        }
        .onChange(of: self.state.isPlaying){ _ in
            self.scheduleHide()
        }
        .onChange(of: self.state.isDragging){ _ in
            self.scheduleHide()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("视频")
    }

    /// 控制按钮
    private var controls: some View {
        ZStack{
            Color.black.opacity(0.3)
            if self.state.isBuffering{
                ProgressView().tint(.white).scaleEffect(1.5)
            } else {
                Button(action: {
                    self.state.playOrPause()
                }){
                    Image(systemName: self.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30))
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
                .accessibilityLabel(self.state.isPlaying ? "暂停视频" : "播放视频")
            }
            VStack{

                //分辨率和帧率显示在左上角,和控制按钮一起显示、隐藏
                if let formatText = self.state.formatText{
                    HStack{
                        Text(formatText)
                            .font(.caption.bold().monospacedDigit())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.black.opacity(0.4)))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, self.isFullScreen ? 16 : 8)
                }
                Spacer()
                self.bottomBar
            }
        }
        .foregroundColor(.white)
    }

    /// 播放时间、进度条和全屏按钮
    private var bottomBar: some View {
        HStack(spacing: 8){
            Text(VideoPlayerView.format(self.state.currentTime))
            Slider(value: Binding(get: { min(self.state.currentTime, max(self.state.duration, 0)) }, set: { self.state.currentTime = $0 }),
                   in: 0...max(self.state.duration, 1)){ isEditing in
                if isEditing{
                    self.state.isDragging = true
                } else {
                    self.state.seek(self.state.currentTime)
                }
            }
            .tint(.white)
            .disabled(self.state.duration == 0)
            .accessibilityLabel("视频进度")
            Text(VideoPlayerView.format(self.state.duration))
            Button(action: self.onFullScreenClick){
                Image(systemName: self.isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(self.isFullScreen ? "退出全屏" : "全屏")
        }
        .font(.caption.monospacedDigit())
        .padding(.horizontal, 12)
        .padding(.bottom, self.isFullScreen ? 16 : 4)
    }

    /// 正在播放并且没有拖动进度条时,一段时间之后自动隐藏控制按钮
    private func scheduleHide() {
        self.hideTask?.cancel()
        guard self.showControls, self.state.isPlaying, !self.state.isDragging else{
            return
        }
        self.hideTask = Task{ @MainActor in
            try? await Task.sleep(nanoseconds: VideoPlayerView.HIDE_CONTROLS_SECONDS * 1_000_000_000)
            if Task.isCancelled || !self.state.isPlaying || self.state.isDragging{
                return
            }
            withAnimation(.easeInOut(duration: 0.2)){
                self.showControls = false
            }
        }
    }

    /// 格式化播放时间
    private static func format(_ seconds: Double) -> String {
        return ((seconds.isFinite ? seconds : 0) * 1000).timeFormat
    }
}

/// 显示视频画面
private struct VideoLayerView: UIViewRepresentable {

    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = self.player
        return view
    }

    func updateUIView(_ view: PlayerLayerView, context: Context) {
        if view.playerLayer.player !== self.player{
            view.playerLayer.player = self.player
        }
    }

    /// 用AVPlayerLayer作为图层的视图,尺寸变化时画面自动跟着变化
    final class PlayerLayerView: UIView {

        override class var layerClass: AnyClass {
            return AVPlayerLayer.self
        }

        var playerLayer: AVPlayerLayer {
            return self.layer as! AVPlayerLayer
        }
    }
}
