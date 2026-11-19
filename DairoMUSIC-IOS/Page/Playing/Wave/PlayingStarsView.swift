//
//  PlayingStarsView.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/19.
//

import SwiftUI

/// 播放页背景:大小不一的十字发光星星慢慢往上飘,忽明忽暗;大的星星飘得快、显得近,小的慢、显得远
struct PlayingStarsView: View {

    /// 是否刷新动画,页面不显示、App不在前台时停止
    let isActive: Bool

    @StateObject private var field = StarField()

    var body: some View {
        TimelineView(.animation(paused: !self.isActive)){ timeline in
            Canvas{ context, size in
                self.field.draw(in: &context, size: size, date: timeline.date)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 星星的位置和动画
final class StarField: ObservableObject {

    private struct Star {
        var x: Double
        var y: Double

        /// 远近(0到1),越大越近:越大、越亮、飘得越快
        let depth: Double
        let size: Double

        /// 往上飘的速度(点/秒)
        let speed: Double

        /// 闪烁的相位和速度
        let phase: Double
        let twinkle: Double

        /// 左右摆动的相位
        let sway: Double

        /// 是否暖色(少数星星偏金色)
        let isWarm: Bool
    }

    /// 星星数量
    private static let COUNT = 34

    private var stars = [Star]()
    private var canvasSize = CGSize.zero
    private var lastDate: Date?

    /// 冷色的星星图片,只生成一次
    @MainActor private static let coolSprite = StarField.sprite(core: Color(red: 200 / 255, green: 215 / 255, blue: 1), ray: Color(red: 190 / 255, green: 205 / 255, blue: 1))

    /// 暖色的星星图片
    @MainActor private static let warmSprite = StarField.sprite(core: Color(red: 1, green: 220 / 255, blue: 170 / 255), ray: Color(red: 1, green: 205 / 255, blue: 150 / 255))

    /// 画这一帧:往上飘,飘出顶部之后从底部重新出现
    @MainActor func draw(in context: inout GraphicsContext, size: CGSize, date: Date) {
        if size != self.canvasSize{
            self.canvasSize = size
            self.stars = (0 ..< StarField.COUNT).map{ _ in StarField.random(in: size, y: Double.random(in: 0 ... size.height)) }
        }
        let dt = min(0.05, max(0, date.timeIntervalSince(self.lastDate ?? date)))
        self.lastDate = date
        let t = date.timeIntervalSinceReferenceDate
        guard let cool = StarField.coolSprite, let warm = StarField.warmSprite else{
            return
        }
        let coolImage = context.resolve(cool)
        let warmImage = context.resolve(warm)
        context.blendMode = .plusLighter
        for i in self.stars.indices{
            self.stars[i].y -= self.stars[i].speed * dt
            if self.stars[i].y < -self.stars[i].size{
                self.stars[i] = StarField.random(in: size, y: size.height + self.stars[i].size)
            }
            let star = self.stars[i]
            let x = star.x + sin(t * 0.4 + star.sway) * 3
            var layer = context
            layer.opacity = (0.45 + 0.55 * (0.5 + 0.5 * sin(t * star.twinkle + star.phase))) * (0.5 + 0.5 * star.depth)
            layer.draw(star.isWarm ? warmImage : coolImage, in: CGRect(x: x - star.size / 2, y: star.y - star.size / 2, width: star.size, height: star.size))
        }
    }

    /// 随机生成一颗星星,小星多,大星少
    private static func random(in size: CGSize, y: Double) -> Star {
        let depth = pow(Double.random(in: 0 ..< 1), 2.2)
        return Star(x: Double.random(in: 0 ... max(1, size.width)), y: y, depth: depth, size: 9 + depth * 32, speed: 6 + depth * 22,
                    phase: Double.random(in: 0 ..< 2 * .pi), twinkle: 0.6 + Double.random(in: 0 ..< 1.6),
                    sway: Double.random(in: 0 ..< 2 * .pi), isWarm: Double.random(in: 0 ..< 1) < 0.18)
    }

    /// 生成星星图片:中间一团光,横竖两道细长的光芒
    @MainActor private static func sprite(core: Color, ray: Color) -> Image? {
        let canvas = Canvas{ context, size in
            let c = size.width / 2
            context.fill(Path(ellipseIn: CGRect(x: c - 30, y: c - 30, width: 60, height: 60)),
                         with: .radialGradient(Gradient(stops: [.init(color: .white, location: 0),
                                                                .init(color: core.opacity(0.7), location: 0.15),
                                                                .init(color: Color(red: 140 / 255, green: 150 / 255, blue: 1, opacity: 0), location: 1)]),
                                               center: CGPoint(x: c, y: c), startRadius: 0, endRadius: 30))
            let gradient = Gradient(stops: [.init(color: ray.opacity(0), location: 0), .init(color: .white, location: 0.5), .init(color: ray.opacity(0), location: 1)])
            var horizontal = Path()
            horizontal.move(to: CGPoint(x: 0, y: c))
            horizontal.addQuadCurve(to: CGPoint(x: size.width, y: c), control: CGPoint(x: c, y: c - 3))
            horizontal.addQuadCurve(to: CGPoint(x: 0, y: c), control: CGPoint(x: c, y: c + 3))
            context.fill(horizontal, with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: c), endPoint: CGPoint(x: size.width, y: c)))
            var vertical = Path()
            vertical.move(to: CGPoint(x: c, y: 0))
            vertical.addQuadCurve(to: CGPoint(x: c, y: size.height), control: CGPoint(x: c + 3, y: c))
            vertical.addQuadCurve(to: CGPoint(x: c, y: 0), control: CGPoint(x: c - 3, y: c))
            context.fill(vertical, with: .linearGradient(gradient, startPoint: CGPoint(x: c, y: 0), endPoint: CGPoint(x: c, y: size.height)))
        }
        .frame(width: 128, height: 128)
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 2
        guard let image = renderer.uiImage else{
            return nil
        }
        return Image(uiImage: image)
    }
}
