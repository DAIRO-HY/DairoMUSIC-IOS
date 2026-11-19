//
//  PlayingWaveDrawing.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/19.
//

import SwiftUI

/// 波形用的颜色,方便调亮、生成不同透明度的颜色
struct WaveColor: Equatable {

    /// 0到1
    let red: Double
    let green: Double
    let blue: Double

    /// 指定透明度的颜色
    func color(_ opacity: Double) -> Color {
        return Color(red: self.red, green: self.green, blue: self.blue, opacity: opacity)
    }

    /// 往白色混合,amount为0时不变,为1时是白色
    func lightened(_ amount: Double) -> WaveColor {
        return WaveColor(red: self.red + (1 - self.red) * amount, green: self.green + (1 - self.green) * amount, blue: self.blue + (1 - self.blue) * amount)
    }
}

/// 波形的调色板:从圆环往外的内圈、中间、外圈三个颜色
struct WavePalette {
    let inner: WaveColor
    let middle: WaveColor
    let outer: WaveColor

    /// 第几个颜色(0内圈 1中间 2外圈)
    func color(at index: Int) -> WaveColor {
        return index == 0 ? self.inner : index == 1 ? self.middle : self.outer
    }

    /// 默认的青蓝、蓝紫、紫粉,中间和外圈的颜色随时间慢慢变化
    /// - Parameter hueShift: 颜色变化的进度(0到1)
    static func standard(hueShift: Double) -> WavePalette {
        return WavePalette(inner: WaveColor(red: 90 / 255, green: 200 / 255, blue: 1),
                           middle: WaveColor(red: (120 + hueShift * 40) / 255, green: 120 / 255, blue: 1),
                           outer: WaveColor(red: 1, green: (170 + hueShift * 40) / 255, blue: 1))
    }

    /// 跟随封面:从封面的主色调出三个深浅不同的颜色
    static func cover(_ base: WaveColor) -> WavePalette {
        return WavePalette(inner: base.lightened(0.55), middle: base.lightened(0.3), outer: base.lightened(0.05))
    }
}

/// 环形波形的尺寸和画法:圆环半径、波形最大高度、点的位置、渐变色
struct WaveGeometry {

    /// 封面直径占画布边长的比例
    static let LOGO_RATIO = 0.525

    /// 圆环比封面大出来的半径(占画布边长的比例),波形从圆环开始往外
    private static let RING_GAP = 0.0075

    /// 波形最大高度占画布边长的比例
    private static let LENGTH_RATIO = 0.15

    /// 画布边长
    let side: Double

    /// 一圈的点数
    let count: Int

    /// 调色板
    let palette: WavePalette

    var center: Double { self.side / 2 }

    /// 圆环半径
    var r0: Double { self.side * (WaveGeometry.LOGO_RATIO / 2 + WaveGeometry.RING_GAP) }

    /// 波形的最大高度
    var length: Double { self.side * WaveGeometry.LENGTH_RATIO }

    /// 圆环
    var innerRing: Path {
        return WaveGeometry.circle(center: self.center, radius: self.r0)
    }

    /// 第i个点的角度,从12点方向开始顺时针
    func angle(_ i: Int) -> Double {
        return Double(i) / Double(self.count) * 2 * .pi - .pi / 2
    }

    /// 第i个点在半径radius上的位置
    func point(_ i: Int, radius: Double, rotation: Double = 0) -> CGPoint {
        let angle = self.angle(i) + rotation
        return CGPoint(x: self.center + cos(angle) * radius, y: self.center + sin(angle) * radius)
    }

    /// 从内半径到外半径的渐变色,颜色从调色板的内圈到外圈
    /// - Parameter inner: 内圈的透明度
    /// - Parameter outer: 外圈的透明度
    func gradient(_ inner: Double, _ outer: Double, from: Double? = nil, to: Double? = nil) -> GraphicsContext.Shading {
        let gradient = Gradient(stops: [
            .init(color: self.palette.inner.color(inner), location: 0),
            .init(color: self.palette.middle.color((inner + outer) / 2), location: 0.48),
            .init(color: self.palette.outer.color(outer), location: 1)
        ])
        return .radialGradient(gradient, center: CGPoint(x: self.center, y: self.center),
                               startRadius: from ?? self.r0, endRadius: to ?? (self.r0 + self.length))
    }

    /// 经过每两点中点的二次贝塞尔曲线,得到平滑的闭合波形
    static func closedCurve(_ points: [CGPoint]) -> Path {
        let n = points.count
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        var path = Path()
        guard n > 2 else{
            return path
        }
        path.move(to: mid(points[n - 1], points[0]))
        for i in 0 ..< n{
            path.addQuadCurve(to: mid(points[i], points[(i + 1) % n]), control: points[i])
        }
        path.closeSubpath()
        return path
    }

    /// 圆
    static func circle(center: Double, radius: Double) -> Path {
        return Path(ellipseIn: CGRect(x: center - radius, y: center - radius, width: radius * 2, height: radius * 2))
    }
}

extension WaveSimulation {

    /// 画这一帧
    func draw(in context: inout GraphicsContext, size: CGSize, style: PlayingWaveStyle, palette: WavePalette) {
        if style == .off{
            return
        }
        let g = WaveGeometry(side: min(size.width, size.height), count: style.pointCount, palette: palette)
        context.blendMode = .plusLighter
        self.drawShockwaves(in: &context, g, style: style)
        switch style {
        case .bars:
            self.drawBars(in: &context, g)
        case .smooth:
            self.drawSmooth(in: &context, g)
        case .aurora:
            self.drawAurora(in: &context, g)
        case .particles:
            self.drawParticles(in: &context, g)
        case .mirror:
            self.drawMirror(in: &context, g)
        case .scope:
            self.drawScope(in: &context, g)
        case .off:
            break
        }
    }

    /// 第i个点的水柱高度
    private func height(_ i: Int, _ count: Int) -> Double {
        return self.bars[self.barIndex(i, count, barCount: self.bars.count)].height
    }

    /// 和相邻的点平滑(首尾相连)
    private static func smooth(_ values: [Double], times: Int = 1) -> [Double] {
        var values = values
        for _ in 0 ..< times{
            let n = values.count
            values = values.indices.map{ (values[($0 - 1 + n) % n] + 2 * values[$0] + values[($0 + 1) % n]) / 4 }
        }
        return values
    }

    /// 低音冲击波:从封面边缘往外扩散的光环,越远越细越淡
    private func drawShockwaves(in context: inout GraphicsContext, _ g: WaveGeometry, style: PlayingWaveStyle) {
        let start = style == .mirror ? g.side * 0.2 : g.r0
        for wave in self.shockwaves{
            let radius = start + wave.radius * g.length * 1.3
            context.stroke(WaveGeometry.circle(center: g.center, radius: radius), with: .color(g.palette.inner.lightened(0.3).color(wave.alpha * 0.55)),
                           lineWidth: g.side * 0.012 * max(0.2, 1 - wave.radius * 0.5))
        }
    }

    /// 水柱:光晕、水柱、内圈光环、顶端水滴、水珠
    private func drawBars(in context: inout GraphicsContext, _ g: WaveGeometry) {
        guard !self.bars.isEmpty else{
            return
        }
        let barWidth = 2 * .pi * g.r0 / Double(g.count) * 0.42
        var path = Path()
        for i in 0 ..< g.count{
            path.move(to: g.point(i, radius: g.r0 + 2))
            path.addLine(to: g.point(i, radius: g.r0 + 2 + self.height(i, g.count) * g.length))
        }
        context.stroke(path, with: g.gradient(0.16, 0.16), style: StrokeStyle(lineWidth: barWidth * 3.2, lineCap: .round))
        context.stroke(path, with: g.gradient(0.85, 0.85), style: StrokeStyle(lineWidth: barWidth, lineCap: .round))
        context.stroke(g.innerRing, with: .color(g.palette.middle.lightened(0.5).color(0.25)), lineWidth: 1)
        var caps = Path()
        for i in 0 ..< g.count{
            let bar = self.bars[self.barIndex(i, g.count, barCount: self.bars.count)]
            if bar.cap - bar.height < 0.015 && bar.height < 0.08{
                continue
            }
            let center = g.point(i, radius: g.r0 + 2 + bar.cap * g.length + barWidth * 1.4)
            caps.addEllipse(in: CGRect(x: center.x - barWidth * 0.55, y: center.y - barWidth * 0.55, width: barWidth * 1.1, height: barWidth * 1.1))
        }
        context.fill(caps, with: .color(g.palette.inner.lightened(0.8).color(0.95)))
        self.drawDrops(in: &context, g, offset: 0, size: barWidth * 2.2)
    }

    /// 圆润:两层平滑波形、轮廓光晕和亮边、慢一拍落下的水面线、内圈光环、水珠
    private func drawSmooth(in context: inout GraphicsContext, _ g: WaveGeometry) {
        guard !self.bars.isEmpty else{
            return
        }
        let lineWidth = g.side * 0.006
        let heights = WaveSimulation.smooth((0 ..< g.count).map{ self.height($0, g.count) })
        let caps = WaveSimulation.smooth((0 ..< g.count).map{ self.bars[self.barIndex($0, g.count, barCount: self.bars.count)].cap })
        let curve = { (values: [Double], offset: Double) in
            WaveGeometry.closedCurve(values.indices.map{ g.point($0, radius: g.r0 + 2 + values[$0] * g.length + offset) })
        }
        let outer = curve(heights, 0)
        let inner = curve(heights.map{ $0 * 0.55 }, 0)
        let surface = curve(caps, lineWidth * 2)

        //填充时挖掉圆环里面的部分
        var outerFill = outer
        outerFill.addPath(g.innerRing)
        context.fill(outerFill, with: g.gradient(0.42, 0.12), style: FillStyle(eoFill: true))
        var innerFill = inner
        innerFill.addPath(g.innerRing)
        context.fill(innerFill, with: g.gradient(0.3, 0.12), style: FillStyle(eoFill: true))
        context.stroke(outer, with: g.gradient(0.18, 0.18), style: StrokeStyle(lineWidth: lineWidth * 4, lineJoin: .round))
        context.stroke(outer, with: g.gradient(0.95, 0.9), style: StrokeStyle(lineWidth: lineWidth * 0.9, lineJoin: .round))
        context.stroke(surface, with: .color(g.palette.inner.lightened(0.8).color(0.4)), style: StrokeStyle(lineWidth: lineWidth * 0.6, lineJoin: .round))
        context.stroke(g.innerRing, with: .color(g.palette.middle.lightened(0.5).color(0.3)), lineWidth: 1)
        self.drawDrops(in: &context, g, offset: lineWidth * 2, size: lineWidth * 2.6)
    }

    /// 甩出去的水珠,快消失时变淡
    private func drawDrops(in context: inout GraphicsContext, _ g: WaveGeometry, offset: Double, size: Double) {
        for drop in self.drops{
            let r = g.r0 + 2 + drop.radius * g.length + offset
            let center = CGPoint(x: g.center + cos(drop.angle) * r, y: g.center + sin(drop.angle) * r)
            let radius = size * drop.scale
            let gradient = Gradient(colors: [g.palette.inner.lightened(0.85).color(min(1, drop.life * 1.5)), g.palette.middle.color(0)])
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                         with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius))
        }
    }

    /// 极光:三条平滑光带(宽的光晕、中等的光带、细的亮线),低音在里、高音在外,各自转动
    private func drawAurora(in context: inout GraphicsContext, _ g: WaveGeometry) {
        guard self.auroraLayers.count == 3 else{
            return
        }
        for layer in 0 ..< 3{
            let bars = self.auroraLayers[layer]
            let heights = WaveSimulation.smooth((0 ..< g.count).map{ bars[self.barIndex($0, g.count, barCount: bars.count)].height }, times: 3)
            let base = g.r0 + g.length * (0.1 + Double(layer) * 0.15)
            let path = WaveGeometry.closedCurve(heights.indices.map{
                g.point($0, radius: base + heights[$0] * g.length * 0.6, rotation: self.auroraAngles[layer])
            })
            let color = g.palette.color(at: layer)
            context.stroke(path, with: .color(color.color(0.14)), style: StrokeStyle(lineWidth: g.side * 0.05, lineJoin: .round))
            context.stroke(path, with: .color(color.color(0.35)), style: StrokeStyle(lineWidth: g.side * 0.016, lineJoin: .round))
            context.stroke(path, with: .color(color.lightened(0.4).color(0.9)), style: StrokeStyle(lineWidth: g.side * 0.004, lineJoin: .round))
        }
        context.stroke(g.innerRing, with: .color(g.palette.middle.lightened(0.5).color(0.3)), lineWidth: 1)
    }

    /// 粒子:每颗光点画一圈淡的光晕和一个亮的核心;贴着圆环的亮边随低音变亮
    private func drawParticles(in context: inout GraphicsContext, _ g: WaveGeometry) {
        var glows = [Path](repeating: Path(), count: 3)
        var cores = Path()
        for particle in self.particles{
            let r = g.r0 + particle.radius * g.length
            let x = g.center + cos(particle.angle) * r
            let y = g.center + sin(particle.angle) * r
            let size = g.side * 0.006 * particle.scale * (0.6 + particle.life * 0.6)
            glows[particle.colorIndex].addEllipse(in: CGRect(x: x - size * 2.4, y: y - size * 2.4, width: size * 4.8, height: size * 4.8))
            cores.addEllipse(in: CGRect(x: x - size * 0.6, y: y - size * 0.6, width: size * 1.2, height: size * 1.2))
        }
        for i in 0 ..< 3{
            context.fill(glows[i], with: .color(g.palette.color(at: i).color(0.22)))
        }
        context.fill(cores, with: .color(g.palette.inner.lightened(0.85).color(0.9)))
        let bass = self.bars.prefix(8).map{ $0.height }.reduce(0, +) / Double(max(1, min(8, self.bars.count)))
        context.stroke(WaveGeometry.circle(center: g.center, radius: g.r0 + 2), with: .color(g.palette.inner.lightened(0.4).color(0.25 + bass * 0.5)),
                       lineWidth: g.side * 0.006)
    }

    /// 镜像:外圈柱子往外,内圈柱子往封面方向,中间一条亮的圆环
    private func drawMirror(in context: inout GraphicsContext, _ g: WaveGeometry) {
        guard !self.bars.isEmpty else{
            return
        }
        let middle = g.side * 0.28
        let outerLength = g.side * 0.14
        let innerLength = g.side * 0.07
        let barWidth = 2 * .pi * middle / Double(g.count) * 0.42
        var outer = Path()
        var inner = Path()
        for i in 0 ..< g.count{
            let h = self.height(i, g.count)
            outer.move(to: g.point(i, radius: middle + 3))
            outer.addLine(to: g.point(i, radius: middle + 3 + h * outerLength))
            inner.move(to: g.point(i, radius: middle - 3))
            inner.addLine(to: g.point(i, radius: middle - 3 - h * innerLength))
        }
        let outerShading = g.gradient(0.9, 0.9, from: middle, to: middle + outerLength)
        let innerGradient = Gradient(colors: [g.palette.middle.color(0.9), g.palette.inner.color(0.9)])
        let innerShading = GraphicsContext.Shading.radialGradient(innerGradient, center: CGPoint(x: g.center, y: g.center),
                                                                  startRadius: middle - innerLength, endRadius: middle)
        var glow = context
        glow.opacity = 0.18
        glow.stroke(outer, with: outerShading, style: StrokeStyle(lineWidth: barWidth * 3, lineCap: .round))
        glow.stroke(inner, with: innerShading, style: StrokeStyle(lineWidth: barWidth * 3, lineCap: .round))
        context.stroke(outer, with: outerShading, style: StrokeStyle(lineWidth: barWidth, lineCap: .round))
        context.stroke(inner, with: innerShading, style: StrokeStyle(lineWidth: barWidth, lineCap: .round))
        context.stroke(WaveGeometry.circle(center: g.center, radius: middle), with: .color(g.palette.inner.lightened(0.85).color(0.55)), lineWidth: 1.2)
    }

    /// 示波器:当前波形一条宽的光晕加一条细的亮线,之前几帧画成越来越淡的残影;中间一圈虚线是没有声音时的位置
    private func drawScope(in context: inout GraphicsContext, _ g: WaveGeometry) {
        let base = g.r0 + g.length * 0.5
        let amplitude = g.length * 0.45 * self.scopeLevel
        for (j, values) in self.scopeHistory.enumerated().reversed(){
            guard !values.isEmpty else{
                continue
            }

            //左右对称,首尾接得上
            let path = WaveGeometry.closedCurve((0 ..< g.count).map{
                g.point($0, radius: base + values[self.barIndex($0, g.count, barCount: values.count)] * amplitude)
            })
            if j == 0{
                context.stroke(path, with: .color(g.palette.inner.color(0.18)), style: StrokeStyle(lineWidth: g.side * 0.03, lineJoin: .round))
                context.stroke(path, with: .color(g.palette.inner.lightened(0.7).color(0.95)), style: StrokeStyle(lineWidth: g.side * 0.005, lineJoin: .round))
            } else {
                let fade = 1 - Double(j) / Double(WaveSimulation.SCOPE_TRAILS)
                context.stroke(path, with: .color(g.palette.middle.color(0.28 * fade)), style: StrokeStyle(lineWidth: g.side * 0.004, lineJoin: .round))
            }
        }
        context.stroke(WaveGeometry.circle(center: g.center, radius: base), with: .color(g.palette.middle.lightened(0.5).color(0.18)),
                       style: StrokeStyle(lineWidth: 1, dash: [2, 6]))
    }
}
