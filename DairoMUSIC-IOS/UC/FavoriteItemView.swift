//
//  FavoriteItemView.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI

/// 歌单列表的一行
struct FavoriteItemView: View {

    /// 封面的大小
    private static let LOGO_SIZE: CGFloat = 52

    /// 封面和歌单名之间的距离
    private static let SPACING: CGFloat = 12

    /// 歌单名到这一行左边的距离,分隔线和歌单名对齐
    static let TEXT_LEADING = FavoriteItemView.LOGO_SIZE + FavoriteItemView.SPACING

    /// 封面图片,"我喜欢"和"最近播放"用固定的图标
    private let logo: String?

    /// 没有封面时的图标
    private let icon: String

    /// 图标颜色
    private let iconColor: Color

    private let name: String

    private let musicCount: Int

    init(_ favorite: FavoriteModel) {
        self.logo = favorite.isLike ? nil : favorite.logo
        self.icon = favorite.isLike ? "heart.fill" : "music.note.list"
        self.iconColor = favorite.isLike ? .like : .secondary
        self.name = favorite.name
        self.musicCount = favorite.musicCount
    }

    init(name: String, icon: String, iconColor: Color, musicCount: Int) {
        self.logo = nil
        self.icon = icon
        self.iconColor = iconColor
        self.name = name
        self.musicCount = musicCount
    }

    var body: some View {
        HStack(spacing: FavoriteItemView.SPACING){
            ZStack{
                if let logo = self.logo{
                    MusicImage(logo, placeholder: self.icon)
                } else {
                    Image(systemName: self.icon)
                        .font(.title2)
                        .foregroundColor(self.iconColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(uiColor: .secondarySystemBackground))
                }
            }
            .frame(width: FavoriteItemView.LOGO_SIZE, height: FavoriteItemView.LOGO_SIZE)
            .cornerRadius(8)
            VStack(alignment: .leading, spacing: 3){
                Text(self.name).font(.body).foregroundColor(.primary).lineLimit(1)
                Text("\(self.musicCount)首").font(.footnote).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
