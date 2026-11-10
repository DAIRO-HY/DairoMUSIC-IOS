//
//  MiniPlayerBar.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

/// 迷你播放条,点击打开播放页面,没有歌曲时不显示
/// 播放页面由迷你播放条弹出,歌单、搜索页面点击歌曲之后也通过它打开播放页面
struct MiniPlayerBar: View {

    @ObservedObject private var player = PlayerManager.shared

    /// 页面传进来的是否显示播放页面,点击歌曲之后页面打开播放页面
    private let showPlayingBinding: Binding<Bool>?

    /// 没有传进来时自己控制是否显示播放页面
    @State private var localShowPlaying = false

    /// 是否显示播放页面
    private var showPlaying: Binding<Bool> {
        return self.showPlayingBinding ?? self.$localShowPlaying
    }

    /// 显示播放列表
    @State private var showPlayList = false

    /// - Parameter showPlaying: 是否显示播放页面,页面需要在点击歌曲之后打开播放页面时传入
    init(showPlaying: Binding<Bool>? = nil) {
        self.showPlayingBinding = showPlaying
    }

    var body: some View {

        //播放页面不放在有歌曲时才显示的播放条上,第一次点击歌曲时播放条和播放页面同时出现
        VStack(spacing: 0){
            self.bar
        }
        //弹出的页面盖在首页上面,用RootView包起来,Toast和Loading显示在弹出的页面上
        .fullScreenCover(isPresented: self.showPlaying){
            RootView{
                PlayingPage()
            }
        }
        .sheet(isPresented: self.$showPlayList){
            RootView{
                PlayListPage()
            }
            .presentationDetents([.medium, .large])
        }
    }

    /// 播放条,没有歌曲时不显示
    @ViewBuilder
    private var bar: some View {
        if let music = self.player.music{
            HStack(spacing: 10){
                MusicImage(music.logo)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2){
                    Text(music.nameText).font(.subheadline).lineLimit(1)
                    Text(self.player.collectMsg ?? music.artistText).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: self.player.playOrPause){
                    Image(systemName: self.player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel(self.player.isPlaying ? "暂停" : "播放")
                Button(action: {
                    self.showPlayList = true
                }){
                    Image(systemName: "list.bullet")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("播放列表")
            }
            .foregroundColor(.primary)
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .padding(.trailing, 4)
            .frame(height: 56)
            .liquidGlassBackground(in: Capsule(), interactive: true)
            .onTapGesture {
                self.showPlaying.wrappedValue = true
            }
        }
    }
}
