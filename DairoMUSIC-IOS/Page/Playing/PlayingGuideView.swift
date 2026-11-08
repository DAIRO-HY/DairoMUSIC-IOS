//
//  PlayingGuideView.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/08.
//

import SwiftUI

/// 播放页的操作引导,只在第一次进入播放页时显示:向右滑动看视频,向左滑动看歌词
struct PlayingGuideView: View {

    /// 关闭引导
    let onDismiss: () -> Void

    /// 箭头左右晃动的动画
    @State private var isMoving = false

    var body: some View {
        ZStack{
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 48){
                Spacer()
                HStack(alignment: .top){
                    self.item(icon: "play.rectangle.fill", title: "视频", tip: "向右滑动", direction: 1)
                    self.item(icon: "text.quote", title: "歌词", tip: "向左滑动", direction: -1)
                }
                Text("播放页左右滑动可以切换视频、封面和歌词")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button(action: self.onDismiss){
                    Text("知道了")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.theme))
                }
                Spacer()
            }
            .frame(maxWidth: 600)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: self.onDismiss)
        .onAppear{
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)){
                self.isMoving = true
            }
        }
    }

    /// 一边的说明,视频在左边要向右滑,歌词在右边要向左滑
    /// - Parameter direction: 手指滑动的方向,箭头朝这个方向晃动,-1:向左 1:向右
    private func item(icon: String, title: String, tip: String, direction: CGFloat) -> some View {
        VStack(spacing: 12){
            Image(systemName: icon)
                .font(.system(size: 40))
            Text(title)
                .font(.title3.bold())
            HStack(spacing: 4){
                if direction < 0{
                    Image(systemName: "chevron.left.2")
                }
                Text(tip)
                if direction > 0{
                    Image(systemName: "chevron.right.2")
                }
            }
            .font(.subheadline)
            .offset(x: self.isMoving ? direction * 8 : 0)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PlayingGuideView{}
}
