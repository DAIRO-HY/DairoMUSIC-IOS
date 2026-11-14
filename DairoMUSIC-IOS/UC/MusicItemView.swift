//
//  MusicItemView.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI

/// 歌曲列表的一行
struct MusicItemView: View {

    private let music: MusicModel

    /// 是否正在播放这一首
    private let isPlaying: Bool

    /// 更多按钮点击事件
    private let onMoreClick: () -> Void

    init(_ music: MusicModel, isPlaying: Bool, onMoreClick: @escaping () -> Void) {
        self.music = music
        self.isPlaying = isPlaying
        self.onMoreClick = onMoreClick
    }

    var body: some View {
        HStack(spacing: 12){
            MusicImage(self.music.logo)
                .frame(width: 46, height: 46)
                .cornerRadius(6)
            VStack(alignment: .leading, spacing: 3){
                Text(self.music.nameText)
                    .font(.body)
                    .foregroundColor(self.isPlaying ? .theme : .primary)
                    .lineLimit(1)
                HStack(spacing: 4){
                    if self.music.id == 0{

                        //采集平台的歌曲,还没有加入曲库
                        Text(self.music.collect?.platform ?? "").font(.caption2)
                            .padding(.horizontal, 3)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary, lineWidth: 0.5))
                    }
                    if (self.music.maxBitRate ?? 0) >= SettingShared.BIT_RATE_LOSSLESS{
                        Text("SQ").font(.caption2).foregroundColor(.theme)
                            .padding(.horizontal, 3)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.theme, lineWidth: 0.5))
                    }
                    Text(self.music.artistAlbumText).font(.footnote).lineLimit(1)

                    //播放次数,只有曲库的搜索结果有
                    if let playCount = self.music.playCount{
                        Spacer(minLength: 4)
                        Label(MusicItemView.playCountText(playCount), systemImage: "play.circle")
                            .font(.caption2)
                            .labelStyle(PlayCountLabelStyle())
                            .fixedSize()
                    }
                }
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if self.isPlaying{
                Image(systemName: "speaker.wave.2.fill").foregroundColor(.theme).font(.footnote)
            }
            Button(action: self.onMoreClick){
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("更多操作")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    /// 播放次数的显示文字,1万以上显示为"1.2万"
    private static func playCountText(_ count: Int) -> String {
        if count < 10000{
            return String(count)
        }
        let text = String(format: "%.1f", Double(count) / 10000)
        return (text.hasSuffix(".0") ? String(text.dropLast(2)) : text) + "万"
    }
}

/// 播放次数:图标和数字挨在一起
private struct PlayCountLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2){
            configuration.icon
            configuration.title
        }
    }
}
