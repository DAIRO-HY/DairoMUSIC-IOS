//
//  MusicInfoPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

/// 歌曲信息和操作,从下方弹出
struct MusicInfoPage: View {

    @StateObject private var vm: MusicInfoViewModel

    /// 显示收藏到歌单的选择
    @State private var showFavoritePicker = false

    /// 显示从歌单删除的确认框
    @State private var showRemoveAlert = false

    /// 显示下载音质的选择
    @State private var showDownloadPicker = false

    /// 服务器配置,不允许下载歌曲时不显示下载按钮
    @ObservedObject private var config = ServerConfig.shared

    @Environment(\.dismiss) private var dismiss

    /// - Parameter favoriteId: 歌曲所在的我的歌单,不在我的歌单里时为nil
    init(_ music: MusicModel, favoriteId: Int64?) {
        self._vm = StateObject(wrappedValue: MusicInfoViewModel(music, favoriteId: favoriteId))
    }

    var body: some View {
        let music = self.vm.music
        SettingStack(embedInNavigationStack: true) {
            SettingPage(title: "歌曲信息") {
                SettingCustomView{
                    HStack(spacing: 12){
                        MusicImage(music.logo)
                            .frame(width: 64, height: 64)
                            .cornerRadius(8)
                        VStack(alignment: .leading, spacing: 4){
                            Text(music.nameText).font(.headline).lineLimit(2)
                            Text(music.artistText).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                }
                SettingGroup{
                    SettingButton(self.vm.isLike ? "取消喜欢" : "喜欢", action: self.vm.onLikeClick)
                        .icon(self.vm.isLike ? "heart.slash.fill" : "heart.fill", backgroundColor: .like)
                    SettingButton("收藏到歌单"){
                        self.showFavoritePicker = true
                    }
                    .icon("plus", backgroundColor: .theme)
                    if self.vm.favorite != nil{
                        SettingButton("从「\(self.vm.favorite!.name)」删除"){
                            self.showRemoveAlert = true
                        }
                        .icon("trash.fill", backgroundColor: .red)
                    }
                    SettingButton("分享", action: self.vm.onShareClick)
                        .icon("square.and.arrow.up", backgroundColor: .blue)
                    if self.config.allowDownloadMusic{
                        SettingButton("下载", tip: self.vm.downloadedText){
                            self.showDownloadPicker = true
                        }
                        .icon("arrow.down.circle.fill", backgroundColor: .green)
                    }
                }
                SettingGroup{
                    SettingText(title: "歌手：" + music.artistText)
                    SettingText(title: "专辑：" + (music.album ?? "未知专辑"))
                    SettingText(title: "最高音质：" + MusicModel.qualityText(music.maxBitRate))
                    SettingText(title: "当前音质：" + MusicModel.qualityText(music.file?.bitRate))
                    SettingText(title: "文件大小：" + (music.file.map{ $0.size.fileSize } ?? "未知"))
                    SettingText(title: "时长：" + (music.duration.map{ $0.timeFormat } ?? "未知"))
                }
                if music.id != 0{
                    SettingGroup{
                        SettingNavigationLink("纠错", tip: "歌名、歌手、专辑不对"){
                            MusicCorrectPage(music).anyView
                        }
                        .icon("pencil", backgroundColor: .orange)
                        SettingNavigationLink("投诉", tip: "音质、内容有问题"){
                            MusicComplaintPage(musicId: music.id).anyView
                        }
                        .icon("exclamationmark.bubble.fill", backgroundColor: .gray)
                    }
                }
            }
        }
        .confirmationDialog("收藏到歌单", isPresented: self.$showFavoritePicker, titleVisibility: .visible){
            ForEach(self.vm.favoriteList, id: \.id){ favorite in
                Button(favorite.name){
                    self.vm.onAddToFavoriteClick(favorite)
                }
            }
            Button("取消", role: .cancel){}
        }
        .confirmationDialog("选择下载的音质", isPresented: self.$showDownloadPicker, titleVisibility: .visible){
            ForEach(MusicDownloadUtil.qualities(maxBitRate: music.maxBitRate), id: \.self){ quality in
                Button(quality.label){
                    self.vm.onDownloadClick(quality)
                }
            }
            Button("取消", role: .cancel){}
        }
        .alert("确定从歌单删除这首歌吗？", isPresented: self.$showRemoveAlert){
            Button("删除", role: .destructive){
                self.vm.onRemoveClick{
                    self.dismiss()
                }
            }
            Button("取消", role: .cancel){}
        }
        .onReceive(NotificationCenter.default.publisher(for: EventName.MUSIC_CHANGE)){ _ in
            self.vm.updateLike()
        }
    }
}
