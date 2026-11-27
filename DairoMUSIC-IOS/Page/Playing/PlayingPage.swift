//
//  PlayingPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

/// 播放页面,左右滑动切换视频、封面和歌词
struct PlayingPage: View {

    /// 视频页面
    private static let TAB_VIDEO = 0

    /// 封面页面
    private static let TAB_COVER = 1

    /// 歌词页面
    private static let TAB_LRC = 2

    /// 竖屏时内容的最大宽度,避免iPad上控制按钮拉得太开
    private static let PORTRAIT_MAX_WIDTH: CGFloat = 640

    /// 横屏时右侧歌曲信息和控制栏的最大宽度
    private static let LANDSCAPE_CONTROL_MAX_WIDTH: CGFloat = 420

    @ObservedObject private var player = PlayerManager.shared

    /// 视频
    @StateObject private var videoVm = VideoViewModel()

    /// 上一次显示的页面,离开视频页面时用来判断
    @State private var lastTab = PlayingPage.TAB_COVER

    /// App前后台状态,进入后台时暂停视频
    @Environment(\.scenePhase) private var scenePhase

    /// 用来判断"我喜欢"状态,歌单变化时刷新
    @State private var likeVersion = 0

    /// 当前显示的页面
    @State private var selectedTab = PlayingPage.TAB_COVER

    /// 显示播放列表
    @State private var showPlayList = false

    /// 要显示详情的歌曲
    @State private var infoMusic: MusicModel?

    /// 第一次进入播放页时提示左边是视频、右边是歌词
    @State private var showGuide = !SettingStore.playingGuideShown

    /// 显示取消离线模式的确认框
    @State private var showOfflineAlert = false

    @Environment(\.dismiss) private var dismiss

    /// 封面页环形波形的样式,在"我的"页面设置
    @AppStorage(SettingStore.KEY_PLAYING_WAVE_STYLE) private var waveStyle = PlayingWaveStyle.bars.rawValue

    /// 是否显示低音冲击波
    @AppStorage(SettingStore.KEY_PLAYING_WAVE_SHOCKWAVE) private var waveShockwave = true

    /// 波形颜色是否跟随封面
    @AppStorage(SettingStore.KEY_PLAYING_WAVE_COVER_COLOR) private var waveCoverColor = true

    /// 页面是否正在显示,不显示时停止背景和波形的动画
    @State private var isVisible = false

    /// App是否在前台,在后台时停止背景和波形的动画
    /// 弹出的页面里scenePhase不准(一直是background),直接用系统通知
    @State private var isAppActive = UIApplication.shared.applicationState == .active

    var body: some View {
        ZStack{
            self.background
            PlayingStarsView(isActive: self.isAnimating).ignoresSafeArea()
            GeometryReader{ geo in
                let isLandscape = geo.size.width > geo.size.height

                //左右滑动的页面不加左右边距,封面的阴影不会被页面边缘切掉;页面里的视频、歌词和其他控件自己加左右边距
                VStack(spacing: 0){
                    self.topBar.padding(.horizontal)
                    if isLandscape{

                        //横屏(iPad):左边视频/封面/歌词,右边歌曲信息和控制栏
                        HStack(spacing: 16){
                            self.tabView
                            VStack(spacing: 0){
                                Spacer()
                                self.infoBar
                                self.bottomBar
                                Spacer()
                            }
                            .frame(width: min(geo.size.width * 0.4, PlayingPage.LANDSCAPE_CONTROL_MAX_WIDTH))
                            .padding(.trailing)
                        }
                    } else {
                        self.tabView
                        VStack(spacing: 0){
                            self.infoBar
                            self.bottomBar
                        }
                        .padding(.horizontal)
                    }
                }
                .frame(maxWidth: isLandscape ? .infinity : PlayingPage.PORTRAIT_MAX_WIDTH)
                .frame(maxWidth: .infinity)
            }
            .foregroundColor(.white)

            //全屏播放视频,切换到下一个视频的过程中保持全屏,显示加载状态
            if self.videoVm.isFullScreen{
                ZStack{
                    Color.black.ignoresSafeArea()
                    if let player = self.videoVm.player{
                        VideoPlayerView(player: player, state: self.videoVm.state, isFullScreen: true, onFullScreenClick: self.videoVm.exitFullScreen,
                                        onPreviousClick: self.videoVm.onPreviousClick, onNextClick: self.videoVm.onNextClick)
                    } else {
                        VStack(spacing: 16){
                            if self.videoVm.isWaiting{
                                ProgressView().tint(.white)
                            }
                            Text(self.videoVm.tip ?? "").font(.subheadline).multilineTextAlignment(.center)
                            Button("退出全屏", action: self.videoVm.exitFullScreen)
                                .buttonStyle(.bordered)
                        }
                        .padding()
                    }
                }
                .zIndex(1)
            }
            if self.showGuide{
                PlayingGuideView{
                    withAnimation(.easeOut(duration: 0.2)){
                        self.showGuide = false
                    }
                }
                .transition(.opacity)
                .zIndex(2)
                .onAppear{
                    SettingStore.playingGuideShown = true
                }
            }
        }
        .statusBarHidden(self.videoVm.isFullScreen)
        .preferredColorScheme(.dark)
        .alert("当前处于离线模式，是否取消离线模式？", isPresented: self.$showOfflineAlert){
            Button("取消离线模式", action: self.player.exitOffline)
            Button("保持", role: .cancel){}
        } message: {
            Text("离线模式下只播放已经离线缓存或缓存的歌曲，取消之后从下一首开始尝试在线播放")
        }
        //弹出的页面用RootView包起来,Toast和Loading显示在弹出的页面上
        .sheet(isPresented: self.$showPlayList){
            RootView{
                PlayListPage()
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: self.$infoMusic){ music in
            RootView{
                MusicInfoPage(music, favoriteId: self.player.favoriteId > 0 ? self.player.favoriteId : nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: EventName.MUSIC_CHANGE)){ _ in
            self.likeVersion += 1
        }
        .onChange(of: self.player.music == nil){ isEmpty in
            if isEmpty{
                self.dismiss()
            }
        }
        .onChange(of: self.selectedTab, perform: self.onTabChange)
        .onChange(of: self.player.index){ _ in

            //在视频页面通过播放列表切换了歌曲,视频跟着切换
            if self.selectedTab == PlayingPage.TAB_VIDEO && !self.videoVm.isShowing(self.player.music){
                self.player.pause()
                self.videoVm.enter()
            }
        }
        .onChange(of: self.player.isPlaying){ isPlaying in

            //音乐开始播放时(例如锁屏界面点了播放)视频暂停
            if isPlaying{
                self.videoVm.pause()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: EventName.SLEEP_TIMER_END)){ _ in
            self.videoVm.pause()
        }
        .onChange(of: self.scenePhase){ phase in
            if phase == .background{
                self.videoVm.pause()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)){ _ in
            self.isAppActive = true
            self.updateSpectrum()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)){ _ in
            self.isAppActive = false
            self.updateSpectrum()
        }
        .onAppear{
            self.isVisible = true
            self.updateSpectrum()
        }
        .onDisappear{
            self.isVisible = false
            self.updateSpectrum()
            if self.selectedTab == PlayingPage.TAB_VIDEO{
                self.videoVm.leave()
            }
        }
    }

    /// 背景:模糊的封面压暗,中间偏上透出一点紫色;颜色跟着每首歌的封面变
    private var background: some View {
        GeometryReader{ geo in
            MusicImage(self.player.music?.logo)
                .frame(width: geo.size.width, height: geo.size.height)
                .blur(radius: 46)
                .saturation(1.25)
                .overlay(Color.black.opacity(0.6))
                .overlay(RadialGradient(colors: [Color(red: 40 / 255, green: 30 / 255, blue: 120 / 255).opacity(0.15),
                                                 Color(red: 5 / 255, green: 7 / 255, blue: 20 / 255).opacity(0.82)],
                                        center: UnitPoint(x: 0.5, y: 0.36), startRadius: 0, endRadius: max(geo.size.width, geo.size.height) * 0.6))
        }
        .background(Color(red: 7 / 255, green: 11 / 255, blue: 24 / 255))
        .ignoresSafeArea()
    }

    /// 背景星星是否动:页面显示、App在前台时
    private var isAnimating: Bool {
        return self.isVisible && self.isAppActive
    }

    /// 封面页的波形是否动
    private var isWaveAnimating: Bool {
        return self.isAnimating && self.selectedTab == PlayingPage.TAB_COVER
    }

    /// 只有封面页的波形显示时才计算频谱,关闭波形时不计算
    private func updateSpectrum() {
        AudioSpectrum.shared.isEnabled = self.isWaveAnimating && self.currentWaveStyle != .off
    }

    /// 设置的波形样式
    private var currentWaveStyle: PlayingWaveStyle {
        return PlayingWaveStyle(rawValue: self.waveStyle) ?? .bars
    }

    /// 视频、封面、歌词左右滑动切换
    private var tabView: some View {
        TabView(selection: self.$selectedTab){
            VideoView(vm: self.videoVm).padding(.horizontal).tag(PlayingPage.TAB_VIDEO)
            self.coverView.tag(PlayingPage.TAB_COVER)
            LrcView().padding(.horizontal).tag(PlayingPage.TAB_LRC)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    /// 进度条和播放控制
    @ViewBuilder
    private var bottomBar: some View {
        if self.selectedTab == PlayingPage.TAB_VIDEO{

            //视频有自己的进度条和控制按钮
            Spacer().frame(height: 24)
        } else {
            PlayingProgressView()
            self.controlBar
        }
    }

    /// 顶部关闭按钮和页面指示
    private var topBar: some View {
        ZStack{
            HStack(spacing: 8){
                ForEach(0 ..< 3, id: \.self){ i in
                    Capsule()
                        .fill(Color.white.opacity(self.selectedTab == i ? 1 : 0.4))
                        .frame(width: self.selectedTab == i ? 18 : 6, height: 6)
                }
            }
            HStack{
                Button(action: {
                    self.dismiss()
                }){
                    Image(systemName: "chevron.down")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("关闭")
                Spacer()

                //歌曲信息
                Button(action: {
                    self.infoMusic = self.player.music
                }){
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("更多操作")
            }
        }
        .padding(.top, 8)
    }

    /// 切换页面,进入视频页面时暂停音乐,视频从头开始播放;离开视频页面时停止视频,音乐保持暂停
    /// 视频可能是后台单独上传的,和音乐的时间轴不一定同步,所以两边的播放进度互不影响
    private func onTabChange(_ tab: Int) {
        if tab == PlayingPage.TAB_VIDEO{
            self.player.pause()
            self.videoVm.enter()
        } else if self.lastTab == PlayingPage.TAB_VIDEO{
            self.videoVm.leave()
        }
        self.lastTab = tab
        self.updateSpectrum()
    }

    /// 封面:圆形封面外面一圈跟着音乐起伏的波形
    private var coverView: some View {
        PlayingWaveView(logo: self.player.music?.logo, isPlaying: self.player.isPlaying,
                        style: self.currentWaveStyle, shockwave: self.waveShockwave, coverColor: self.waveCoverColor, isActive: self.isWaveAnimating)
            .padding(.horizontal, 8)
    }

    /// 歌名、歌手、喜欢和更多按钮
    private var infoBar: some View {
        VStack(alignment: .leading, spacing: 2){

            //歌名单独一行,长歌名能显示得更完整
            Text(self.player.music?.nameText ?? "")
                .font(.title2.bold())
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12){
                Text(self.player.collectMsg ?? self.player.music?.artistAlbumText ?? "")
                    .font(.subheadline)
                    .foregroundColor(Color(red: 220 / 255, green: 225 / 255, blue: 1).opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                self.infoButtons
            }
        }
        .padding(.top)
    }

    /// 歌手后面的按钮:离线模式、喜欢
    @ViewBuilder
    private var infoButtons: some View {
        //离线模式时显示,点击之后可以取消离线模式
        if self.player.isOffline{
            Button(action: {
                self.showOfflineAlert = true
            }){
                Image(systemName: "wifi.slash")
                    .font(.title3)
                    .foregroundColor(.orange)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("离线模式")
        }
        let isLike = self.isLike
        Button(action: {
            if let music = self.player.music{
                MusicStore.toggleLike(music)
            }
        }){
            Image(systemName: isLike ? "heart.fill" : "heart")
                .font(.title2)
                .foregroundColor(isLike ? .like : .white)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(isLike ? "取消喜欢" : "喜欢")
    }

    /// 是否"我喜欢"的歌曲
    private var isLike: Bool {
        _ = self.likeVersion
        guard let music = self.player.music, music.id != 0 else{
            return false
        }
        return MusicStore.isLike(music.id)
    }

    /// 播放控制
    private var controlBar: some View {
        HStack{
            Button(action: self.player.switchOrderType){
                Image(systemName: self.player.orderType.icon).font(.title3)
            }
            .accessibilityLabel(self.player.orderType.label)
            Spacer()
            Button(action: self.player.previous){
                Image(systemName: "backward.fill").font(.title)
            }
            .accessibilityLabel("上一曲")
            Spacer()
            Button(action: self.player.playOrPause){
                PlayingPlayButton(isPlaying: self.player.isPlaying, isLoading: self.player.isLoading)
            }
            .accessibilityLabel(self.player.isPlaying ? "暂停" : "播放")
            Spacer()
            Button(action: { self.player.next() }){
                Image(systemName: "forward.fill").font(.title)
            }
            .accessibilityLabel("下一曲")
            Spacer()
            Button(action: {
                self.showPlayList = true
            }){
                Image(systemName: "list.bullet").font(.title3)
            }
            .accessibilityLabel("播放列表")
        }
        .buttonStyle(.plain)
        .padding(.vertical, 24)
    }
}

/// 播放进度条,单独一个视图,进度变化时只刷新这一部分;两边显示时间,点击、拖动跳到对应位置
private struct PlayingProgressView: View {

    @ObservedObject private var progress = PlayerProgress.shared

    var body: some View {
        HStack(spacing: 12){
            Text(PlayingProgressView.format(self.progress.currentTime)).frame(width: 44, alignment: .leading)
            GeometryReader{ geo in
                let ratio = self.progress.duration > 0 ? min(1, max(0, self.progress.currentTime / self.progress.duration)) : 0
                ZStack(alignment: .leading){
                    Capsule().fill(Color.white.opacity(0.18)).frame(height: 4)
                    Capsule().fill(Color(red: 226 / 255, green: 230 / 255, blue: 1)).frame(width: geo.size.width * ratio, height: 4)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: Color(red: 170 / 255, green: 180 / 255, blue: 1, opacity: 0.9), radius: 6)
                        .offset(x: geo.size.width * ratio - 7)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged{
                        guard self.progress.duration > 0 else{
                            return
                        }
                        self.progress.isDragging = true
                        self.progress.currentTime = min(1, max(0, $0.location.x / geo.size.width)) * self.progress.duration
                    }
                    .onEnded{ _ in
                        guard self.progress.isDragging else{
                            return
                        }
                        self.progress.isDragging = false
                        PlayerManager.shared.seek(self.progress.currentTime)
                    })
            }
            .frame(height: 24)
            .accessibilityElement()
            .accessibilityLabel("播放进度")
            .accessibilityValue(PlayingProgressView.format(self.progress.currentTime))
            .accessibilityAdjustableAction{ direction in
                let step = direction == .increment ? 5.0 : -5.0
                PlayerManager.shared.seek(min(self.progress.duration, max(0, self.progress.currentTime + step)))
            }
            Text(PlayingProgressView.format(self.progress.duration)).frame(width: 44, alignment: .trailing)
        }
        .font(.caption.monospacedDigit())
        .foregroundColor(.white.opacity(0.6))
    }

    /// 格式化播放时间
    private static func format(_ seconds: Double) -> String {
        return ((seconds.isFinite ? seconds : 0) * 1000).timeFormat
    }
}

/// 播放、暂停按钮:蓝色渐变的圆形按钮,下方有蓝色光晕,外面一圈淡淡的光环,暂停时光晕变暗
private struct PlayingPlayButton: View {

    let isPlaying: Bool

    let isLoading: Bool

    /// 按钮大小
    private static let SIZE: CGFloat = 80

    var body: some View {
        ZStack{
            Circle()
                .fill(LinearGradient(colors: [Color(red: 127 / 255, green: 180 / 255, blue: 1), Color(red: 75 / 255, green: 111 / 255, blue: 240 / 255)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color(red: 75 / 255, green: 111 / 255, blue: 240 / 255).opacity(self.isPlaying ? 0.55 : 0.35),
                        radius: self.isPlaying ? 18 : 12, y: self.isPlaying ? 12 : 8)
                .padding(5)
                .background(Circle().fill(Color(red: 127 / 255, green: 180 / 255, blue: 1).opacity(self.isPlaying ? 0.12 : 0.06)))
            if self.isLoading{
                ProgressView().tint(.white)
            } else {
                Image(systemName: self.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)

                    //播放的三角形看起来偏左,往右挪一点
                    .offset(x: self.isPlaying ? 0 : 3)
            }
        }
        .frame(width: PlayingPlayButton.SIZE, height: PlayingPlayButton.SIZE)
        .animation(.easeOut(duration: 0.3), value: self.isPlaying)
    }
}

#Preview {
    PlayingPage()
}
