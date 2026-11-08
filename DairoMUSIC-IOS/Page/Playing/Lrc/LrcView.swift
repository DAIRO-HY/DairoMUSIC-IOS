//
//  LrcView.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI

/// 歌词,当前播放的那一行高亮并滚动到中间,点击歌词跳转到对应的位置
struct LrcView: View {

    @StateObject private var vm = LrcViewModel()

    @ObservedObject private var progress = PlayerProgress.shared

    var body: some View {
        if let tip = self.vm.tip{
            Text(tip).foregroundColor(.white.opacity(0.7))
        } else {
            let currentIndex = self.vm.currentIndex(self.progress.currentTime)
            ScrollViewReader{ proxy in
                ScrollView(showsIndicators: false){
                    LazyVStack(spacing: 18){
                        ForEach(self.vm.lines.indices, id: \.self){ i in
                            let isCurrent = i == currentIndex
                            Text(self.vm.lines[i].text)
                                .font(isCurrent ? .title3.bold() : .body)
                                .foregroundColor(.white.opacity(isCurrent ? 1 : 0.55))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .id(i)
                                .onTapGesture {
                                    PlayerManager.shared.seek(self.vm.lines[i].time)
                                }
                        }
                    }
                    .padding(.vertical, 200)
                    .padding(.horizontal)
                }
                .mask(LinearGradient(colors: [.clear, .black, .black, .clear], startPoint: .top, endPoint: .bottom))
                .onChange(of: currentIndex){ index in
                    guard let index else{
                        return
                    }
                    withAnimation {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
                .onAppear{
                    if let currentIndex{
                        proxy.scrollTo(currentIndex, anchor: .center)
                    }
                }
            }
        }
    }
}
