//
//  HomeTabView.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

//tab页面标记
enum TabPage{
    case DISCOVER_PAGE//发现页面
    case FAVORITE_PAGE//音乐页面
    case MINE_PAGE//我的页面
}

/// 首页底部:迷你播放条和Tab按钮
struct HomeTabView: View {

    ///当前选中的页面标记
    private let pageTag: TabPage
    init(_ pageTag: TabPage) {
        self.pageTag = pageTag
    }

    var body: some View {
        VStack(spacing: 6){
            MiniPlayerBar()
            HStack{
                self.tabBtn("发现", "safari.fill", isSelected: self.pageTag == .DISCOVER_PAGE){
                    DiscoverPage().relaunch()
                }
                self.tabBtn("音乐", "music.note.list", isSelected: self.pageTag == .FAVORITE_PAGE){
                    FavoritePage().relaunch()
                }
                self.tabBtn("我的", "person.fill", isSelected: self.pageTag == .MINE_PAGE){
                    MinePage().relaunch()
                }
            }
            .padding(.horizontal, 4)
            .frame(height: 60)
            .liquidGlassBackground(in: Capsule())
        }
        .frame(maxWidth: 420)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private func tabBtn(_ text: String, _ icon: String, isSelected: Bool, action: @escaping ()->Void) -> some View{
        Button(action: {
            if !isSelected{//不能用disabled,会让选中的按钮变灰
                action()
            }
        }){
            let label = VStack(spacing: 3){
                Image(systemName: icon).font(.title3)
                Text(text).font(.footnote)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Capsule())
            if isSelected{

                //玻璃叠在玻璃上几乎看不出来,加一点颜色
                label.liquidGlassBackground(Color.primary.opacity(0.12), in: Capsule())
            } else {
                label
            }
        }
        .foregroundColor(.primary)
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack{
        Spacer()
        HomeTabView(.DISCOVER_PAGE)
    }
}
