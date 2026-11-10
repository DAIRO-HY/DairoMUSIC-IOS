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
    @State private var showGuide = !SettingShared.playingGuideShown

    /// 显示取消离线模式的确认框
    @State private var showOfflineAlert = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack{

            //模糊的封面作为背景
            GeometryReader{ geo in
                MusicImage(self.player.music?.logo)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blur(radius: 40)
                    .overlay(Color.black.opacity(0.45))
            }
            .ignoresSafeArea()
            GeometryReader{ geo in
                let isLandscape = geo.size.width > geo.size.height
                VStack(spacing: 0){
                    self.topBar
                    if isLandscape{

                        //横屏(iPad):左边视频/封面/歌词,右边歌曲信息和控制栏
                        HStack(spacing: 32){
                            self.tabView
                            VStack(spacing: 0){
                                Spacer()
                                self.infoBar
                                self.bottomBar
                                Spacer()
                            }
                            .frame(width: min(geo.size.width * 0.4, PlayingPage.LANDSCAPE_CONTROL_MAX_WIDTH))
                        }
                    } else {
                        self.tabView
                        self.infoBar
                        self.bottomBar
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: isLandscape ? .infinity : PlayingPage.PORTRAIT_MAX_WIDTH)
                .frame(maxWidth: .infinity)
            }
            .foregroundColor(.white)

            //全屏播放视频,切换到下一个视频的过程中保持全屏,显示加载状态
            if self.videoVm.isFullScreen{
                ZStack{
                    Color.black.ignoresSafeArea()
                    if let player = self.videoVm.player{
                        VideoPlayerView(player: player, state: self.videoVm.state, isFullScreen: true, onFullScreenClick: self.videoVm.exitFullScreen)
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
                    SettingShared.playingGuideShown = true
                }
            }
        }
        .statusBarHidden(self.videoVm.isFullScreen)
        .preferredColorScheme(.dark)
        .alert("当前处于离线模式，是否取消离线模式？", isPresented: self.$showOfflineAlert){
            Button("取消离线模式", action: self.player.exitOffline)
            Button("保持", role: .cancel){}
        } message: {
            Text("离线模式下只播放已经下载或缓存的歌曲，取消之后从下一首开始尝试在线播放")
        }
        .sheet(isPresented: self.$showPlayList){
            PlayListPage().presentationDetents([.medium, .large])
        }
        .sheet(item: self.$infoMusic){ music in
            MusicInfoPage(music, favoriteId: self.player.favoriteId > 0 ? self.player.favoriteId : nil)
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
        .onDisappear{
            if self.selectedTab == PlayingPage.TAB_VIDEO{
                self.videoVm.leave()
            }
        }
    }

    /// 视频、封面、歌词左右滑动切换
    private var tabView: some View {
        TabView(selection: self.$selectedTab){
            VideoView(vm: self.videoVm).tag(PlayingPage.TAB_VIDEO)
            self.coverView.tag(PlayingPage.TAB_COVER)
            LrcView().tag(PlayingPage.TAB_LRC)
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
    }

    /// 封面
    private var coverView: some View {
        GeometryReader{ geo in
            let size = min(geo.size.width - 40, geo.size.height - 40)
            MusicImage(self.player.music?.logo)
                .frame(width: size, height: size)
                .cornerRadius(24)
                .shadow(radius: 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 歌名、歌手、喜欢和更多按钮
    private var infoBar: some View {
        HStack(spacing: 12){
            VStack(alignment: .leading, spacing: 4){
                Text(self.player.music?.nameText ?? "").font(.title2.bold()).lineLimit(1)
                Text(self.player.collectMsg ?? self.player.music?.artistAlbumText ?? "").font(.subheadline).opacity(0.7).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
                    MusicShared.toggleLike(music)
                }
            }){
                Image(systemName: isLike ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(isLike ? .like : .white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(isLike ? "取消喜欢" : "喜欢")
            Button(action: {
                self.infoMusic = self.player.music
            }){
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("更多操作")
        }
        .padding(.top)
    }

    /// 是否"我喜欢"的歌曲
    private var isLike: Bool {
        _ = self.likeVersion
        guard let music = self.player.music, music.id != 0 else{
            return false
        }
        return MusicShared.isLike(music.id)
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
                ZStack{
                    Image(systemName: self.player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 68, height: 68)
                    if self.player.isLoading{
                        ProgressView().tint(.black)
                    }
                }
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

/// 播放进度条,单独一个视图,进度变化时只刷新这一部分
private struct PlayingProgressView: View {

    @ObservedObject private var progress = PlayerProgress.shared

    var body: some View {
        VStack(spacing: 2){
            Slider(value: Binding(get: { min(self.progress.currentTime, self.progress.duration) }, set: { self.progress.currentTime = $0 }),
                   in: 0...max(self.progress.duration, 1)){ isEditing in
                self.progress.isDragging = isEditing
                if !isEditing{
                    PlayerManager.shared.seek(self.progress.currentTime)
                }
            }
            .tint(.white)
            .disabled(self.progress.duration == 0)
            HStack{
                Text(PlayingProgressView.format(self.progress.currentTime))
                Spacer()
                Text(PlayingProgressView.format(self.progress.duration))
            }
            .font(.caption.monospacedDigit())
            .opacity(0.7)
        }
    }

    /// 格式化播放时间
    private static func format(_ seconds: Double) -> String {
        return ((seconds.isFinite ? seconds : 0) * 1000).timeFormat
    }
}

#Preview {
    PlayingPage()
}
