//
//  MusicListPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

/// 歌单里的歌曲列表,我的歌单、推荐的歌单、最近播放都使用这个页面
struct MusicListPage: View {

    @StateObject private var vm: MusicListViewModel

    @ObservedObject private var player = PlayerManager.shared

    /// 要显示详情的歌曲
    @State private var infoMusic: MusicModel?

    /// 显示清空最近播放的确认框
    @State private var showClearAlert = false

    /// 显示播放页面
    @State private var showPlaying = false

    /// 显示全部下载的音质选择
    @State private var showDownloadPicker = false

    /// 服务器配置,不允许下载歌曲时不显示全部下载按钮
    @ObservedObject private var config = ServerConfig.shared

    init(favoriteId: Int64, name: String) {
        self._vm = StateObject(wrappedValue: MusicListViewModel(favoriteId: favoriteId, name: name))
    }

    var body: some View {
        List{
            self.header
                .listRowSeparator(.hidden)
            if self.vm.musicList.isEmpty && !self.vm.isLoading{
                Text("没有歌曲")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowSeparator(.hidden)
            }
            ForEach(Array(self.vm.musicList.enumerated()), id: \.element.listId){ i, music in
                MusicItemView(music, isPlaying: self.isPlaying(music)){
                    self.infoMusic = music
                }
                .onTapGesture {
                    self.vm.play(i)

                    //点击歌曲之后打开播放页面
                    self.showPlaying = true
                }
                .swipeActions(edge: .trailing){
                    if self.vm.isMine{
                        Button("删除", role: .destructive){
                            self.vm.remove(music)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay{
            if self.vm.isLoading && self.vm.musicList.isEmpty{
                ProgressView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0){
            MiniPlayerBar(showPlaying: self.$showPlaying).padding(.horizontal).padding(.bottom, 4)
        }
        .navigationTitle(self.vm.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar{
            if self.vm.isMine && !self.vm.isLike{
                NavigationLink(destination: FavoriteEditPage(favoriteId: self.vm.favoriteId)){
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("编辑歌单")
            }
            if self.vm.favoriteId == FavoriteType.LATE && !self.vm.musicList.isEmpty{
                Button(action: {
                    self.showClearAlert = true
                }){
                    Image(systemName: "trash")
                }
                .accessibilityLabel("清空最近播放")
            }
        }
        //弹出的页面用RootView包起来,Toast和Loading显示在弹出的页面上
        .sheet(item: self.$infoMusic){ music in
            RootView{
                MusicInfoPage(music, favoriteId: self.vm.isMine ? self.vm.favoriteId : nil)
            }
        }
        .confirmationDialog("选择下载的音质", isPresented: self.$showDownloadPicker, titleVisibility: .visible){
            ForEach(MusicDownloadUtil.QUALITIES, id: \.self){ quality in
                Button(quality.label){
                    MusicDownloadUtil.downloadAll(self.vm.musicList, quality: quality)
                }
            }
            Button("取消", role: .cancel){}
        } message: {
            Text("歌曲没有选择的音质时下载最接近的音质")
        }
        .alert("确定清空最近播放吗？", isPresented: self.$showClearAlert){
            Button("清空", role: .destructive, action: self.vm.clearLate)
            Button("取消", role: .cancel){}
        }
    }

    /// 歌单信息
    private var header: some View {
        HStack(spacing: 12){
            ZStack{
                if self.vm.isLike{
                    Image(systemName: "heart.fill").font(.largeTitle).foregroundColor(.like)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(uiColor: .secondarySystemBackground))
                } else if self.vm.favoriteId == FavoriteType.LATE{
                    Image(systemName: "clock.fill").font(.largeTitle).foregroundColor(.theme)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(uiColor: .secondarySystemBackground))
                } else {
                    MusicImage(self.vm.logo, placeholder: "music.note.list")
                }
            }
            .frame(width: 96, height: 96)
            .cornerRadius(10)
            VStack(alignment: .leading, spacing: 6){
                Text(self.vm.name).font(.title3).bold().lineLimit(2)
                if let description = self.vm.description, !description.isEmpty{
                    Text(description).font(.footnote).foregroundColor(.secondary).lineLimit(3)
                }
                HStack{
                    Text("\(self.vm.musicList.count)首").font(.footnote).foregroundColor(.secondary)
                    Spacer()
                    if self.config.allowDownloadMusic && !self.vm.musicList.isEmpty{
                        Button(action: {
                            if self.config.checkDownloadVip(){
                                self.showDownloadPicker = true
                            }
                        }){
                            Label("全部下载", systemImage: "arrow.down.circle")
                                .font(.footnote)
                                .foregroundColor(.theme)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    /// 是否正在播放的歌曲,只在播放的是这个列表时显示
    private func isPlaying(_ music: MusicModel) -> Bool {
        guard self.player.favoriteId == self.vm.favoriteId, let playing = self.player.music else{
            return false
        }
        return playing.isSameMusic(music)
    }
}
