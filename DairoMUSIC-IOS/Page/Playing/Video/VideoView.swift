//
//  VideoView.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/08.
//

import SwiftUI

/// 播放页的视频,全屏时视频显示在播放页的最上层,这里只显示黑色背景
struct VideoView: View {

    @ObservedObject var vm: VideoViewModel

    var body: some View {
        VStack(spacing: 16){
            Spacer()
            ZStack{
                Color.black
                if let player = self.vm.player{
                    if !self.vm.isFullScreen{
                        VideoPlayerView(player: player, state: self.vm.state, isFullScreen: false, onFullScreenClick: self.vm.enterFullScreen)
                    }
                } else {
                    VStack(spacing: 12){
                        if self.vm.isWaiting{
                            ProgressView().tint(.white)
                        }
                        Text(self.vm.tip ?? "").font(.subheadline).multilineTextAlignment(.center)
                        if self.vm.isOriginalOnly && !self.vm.isWaiting && self.vm.tip == "当前音乐未收藏,只能播放原画版"{
                            Button("播放原画版"){
                                self.vm.showOriginalConfirm = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .cornerRadius(12)
            self.toolbar
            Spacer()
        }
        .alert("提示", isPresented: self.$vm.showOriginalConfirm){
            Button("继续播放", action: self.vm.onOriginalConfirm)
            Button("取消", role: .cancel){}
        } message: {
            Text("当前音乐未收藏，只能播放原画版，原画需要消耗更多流量，是否继续播放？")
        }
        .confirmationDialog("是否保存到相册？", isPresented: self.$vm.showSaveAlbumConfirm, titleVisibility: .visible){
            Button("下载并保存到相册"){
                self.vm.download(saveAlbum: true)
            }
            Button("只下载"){
                self.vm.download(saveAlbum: false)
            }
            Button("取消", role: .cancel){}
        }
    }

    /// 清晰度、下一个视频、下载,三个按钮平分宽度,不允许下载视频时不显示下载按钮,下一个视频仍然在中间
    private var toolbar: some View {
        HStack(spacing: 0){
            Menu{
                Picker("清晰度", selection: Binding(get: { self.vm.quality }, set: { self.vm.onQualityChange($0) })){
                    Text("流畅").tag(SettingShared.VIDEO_QUALITY_SMOOTH)
                    Text("原画").tag(SettingShared.VIDEO_QUALITY_ORIGINAL)
                }
            } label: {
                Label(self.qualityText, systemImage: "sparkles.tv")
            }
            .disabled(self.vm.isOriginalOnly)
            .accessibilityLabel("清晰度")
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: self.vm.onNextClick){
                Image(systemName: "forward.end.fill")
            }
            .accessibilityLabel("下一个视频")
            .frame(maxWidth: .infinity)
            Group{
                if self.vm.allowDownload{
                    Button(action: self.vm.onDownloadClick){
                        if let percent = self.vm.downloadPercent{
                            Label("\(percent)%", systemImage: "arrow.down.circle")
                        } else {
                            Label(self.vm.isDownloaded ? "已下载" : "下载", systemImage: self.vm.isDownloaded ? "checkmark.circle" : "arrow.down.circle")
                        }
                    }
                    .disabled(!self.vm.canDownload)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.subheadline)
        .labelStyle(.titleAndIcon)
        .foregroundColor(.white)
        .padding(.horizontal, 4)
    }

    /// 清晰度说明
    private var qualityText: String {
        if self.vm.isOriginalOnly{
            return "原画"
        }
        return self.vm.quality == SettingShared.VIDEO_QUALITY_ORIGINAL ? "原画" : "流畅"
    }
}
