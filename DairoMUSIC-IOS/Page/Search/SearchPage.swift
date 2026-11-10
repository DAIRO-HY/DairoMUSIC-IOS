//
//  SearchPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

struct SearchPage: View {

    @StateObject private var vm = SearchViewModel()

    @ObservedObject private var player = PlayerManager.shared

    /// 要显示详情的歌曲
    @State private var infoMusic: MusicModel?

    /// 输入框焦点
    @FocusState private var isFocused: Bool

    var body: some View {
        List{
            if self.vm.isSearched{
                self.resultView
            } else {
                self.historyView
            }
        }
        .listStyle(.plain)
        .scrollTopBar{
            self.searchBar
        }
        .safeAreaInset(edge: .bottom, spacing: 0){
            MiniPlayerBar().padding(.horizontal).padding(.bottom, 4)
        }
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        //弹出的页面用RootView包起来,Toast和Loading显示在弹出的页面上
        .sheet(item: self.$infoMusic){ music in
            RootView{
                MusicInfoPage(music, favoriteId: nil)
            }
        }
        .onAppear{
            if !self.vm.isSearched{
                self.isFocused = true
            }
        }
    }

    /// 搜索框
    private var searchBar: some View {
        HStack{
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("搜索歌曲、歌手", text: self.$vm.key)
                .focused(self.$isFocused)
                .submitLabel(.search)
                .onSubmit(self.vm.search)
                .onChange(of: self.vm.key){ _ in
                    self.vm.onKeyChange()
                }
            if !self.vm.key.isEmpty{
                Button(action: {
                    self.vm.key = ""
                    self.isFocused = true
                }){
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除")
            }
        }
        .padding(.horizontal)
        .frame(height: 40)
        .liquidGlassBackground(in: Capsule())
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    /// 搜索历史
    @ViewBuilder
    private var historyView: some View {
        if !self.vm.history.isEmpty{
            Section{
                ForEach(self.vm.history, id: \.self){ key in
                    Button(action: {
                        self.isFocused = false
                        self.vm.onHistoryClick(key)
                    }){
                        Label(key, systemImage: "clock.arrow.circlepath").foregroundColor(.primary)
                    }
                }
            } header: {
                HStack{
                    Text("搜索历史")
                    Spacer()
                    Button("清空", action: self.vm.onClearHistoryClick).font(.subheadline)
                }
            }
        }
    }

    /// 搜索结果
    @ViewBuilder
    private var resultView: some View {
        Section("曲库"){
            if self.vm.musicList.isEmpty{
                Text("曲库里没有找到").foregroundColor(.secondary)
            }
            self.musicRows(self.vm.musicList)
        }
        Section{
            if self.vm.isCollectSearching{
                HStack{
                    ProgressView()
                    Text("正在搜索采集平台").foregroundColor(.secondary).padding(.leading, 6)
                }
            } else if self.vm.collectList.isEmpty{
                Text("采集平台没有找到").foregroundColor(.secondary)
            }
            self.musicRows(self.vm.collectList)
        } header: {
            Text("采集平台")
        } footer: {
            Text("采集平台的歌曲加入歌单之后会自动保存到曲库").font(.footnote).foregroundColor(.secondary)
        }
    }

    /// 歌曲列表
    private func musicRows(_ list: [MusicModel]) -> some View {
        ForEach(Array(list.enumerated()), id: \.element.listId){ i, music in
            MusicItemView(music, isPlaying: self.isPlaying(music)){
                self.infoMusic = music
            }
            .onTapGesture {
                self.isFocused = false
                self.vm.play(list, index: i)
            }
        }
    }

    /// 是否正在播放的歌曲
    private func isPlaying(_ music: MusicModel) -> Bool {
        guard self.player.favoriteId == FavoriteType.SEARCH, let playing = self.player.music else{
            return false
        }
        return playing.isSameMusic(music)
    }
}

#Preview {
    NavigationView{
        SearchPage()
    }
}
