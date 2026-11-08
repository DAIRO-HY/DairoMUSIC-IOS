//
//  PlayListPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI

/// 当前播放列表
struct PlayListPage: View {

    @ObservedObject private var player = PlayerManager.shared

    var body: some View {
        NavigationView{
            ScrollViewReader{ proxy in
                List{
                    ForEach(Array(self.player.playList.enumerated()), id: \.offset){ i, music in
                        let isCurrent = i == self.player.index
                        HStack{
                            VStack(alignment: .leading, spacing: 2){
                                Text(music.nameText).foregroundColor(isCurrent ? .theme : .primary).lineLimit(1)
                                Text(music.artistText).font(.footnote).foregroundColor(.secondary).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if isCurrent{
                                Image(systemName: "speaker.wave.2.fill").foregroundColor(.theme).font(.footnote)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.player.playAt(i)
                        }
                        .id(i)
                    }
                    .onDelete{ indexSet in
                        indexSet.sorted(by: >).forEach{ self.player.remove(at: $0) }
                    }
                }
                .listStyle(.plain)
                .onAppear{
                    proxy.scrollTo(self.player.index, anchor: .center)
                }
            }
            .navigationTitle("播放列表(\(self.player.playList.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement: .navigationBarLeading){
                    Button(action: self.player.switchOrderType){
                        Label(self.player.orderType.label, systemImage: self.player.orderType.icon)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
        //iPad上默认是左右分栏,这里要全屏显示
        .navigationViewStyle(.stack)
    }
}
