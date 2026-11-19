//
//  PlayingWaveView.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/19.
//

import SwiftUI

/// 播放页环形波形的样式,在"我的"页面设置;声明的顺序就是设置里的顺序,值保存在本地,不能改
enum PlayingWaveStyle: Int, CaseIterable {

    /// 一根根细水柱,顶端有水滴
    case bars = 0

    /// 两层平滑曲线,外面有一条慢一拍落下的水面线
    case smooth = 1

    /// 低音、中音、高音三条半透明光带,各自转动、起伏
    case aurora = 3

    /// 圆环每个方向往外喷光点,喷多快多远跟着频段强度
    case particles = 4

    /// 外圈柱子往外冲,内圈柱子同时往封面方向压进去
    case mirror = 5

    /// 声音的原始波形绕成一圈,后面拖着残影
    case scope = 6

    /// 不显示波形,只有转动的圆形封面,不计算频谱
    case off = 2

    /// 设置里显示的名称
    var label: String {
        switch self {
        case .bars:
            return "水柱"
        case .smooth:
            return "圆润"
        case .aurora:
            return "极光"
        case .particles:
            return "粒子"
        case .mirror:
            return "镜像"
        case .scope:
            return "示波器"
        case .off:
            return "关闭"
        }
    }

    /// 一圈的点数,左右对称,只算一半;关闭时为0
    var pointCount: Int {
        switch self {
        case .bars, .particles:
            return 120
        case .smooth:
            return 72
        case .aurora:
            return 96
        case .mirror:
            return 90
        case .scope:
            return AudioSpectrum.WAVE_COUNT * 2
        case .off:
            return 0
        }
    }

    /// 封面直径占画布边长的比例,镜像样式里面还有一圈往里压的柱子,封面小一些
    var logoRatio: Double {
        return self == .mirror ? 0.4 : WaveGeometry.LOGO_RATIO
    }
}

/// 播放页封面:圆形封面跟着播放慢慢转,外面一圈跟着实时频谱起伏的波形
/// 可以叠加低音冲击波(鼓点时从封面往外扩散一圈光环),波形颜色可以跟随封面的主色
struct PlayingWaveView: View {

    /// 封面地址
    let logo: String?

    /// 是否正在播放,暂停时波形全部落回、封面停止转动
    let isPlaying: Bool

    /// 波形样式
    let style: PlayingWaveStyle

    /// 是否显示低音冲击波
    let shockwave: Bool

    /// 波形颜色是否跟随封面
    let coverColor: Bool

    /// 是否刷新动画,页面不显示、App不在前台时停止
    let isActive: Bool

    /// 动画的状态,每一帧更新,不需要刷新视图
    @StateObject private var simulation = WaveSimulation()

    /// 封面的主色,跟随封面颜色时才取
    @State private var tint: WaveColor?

    var body: some View {
        GeometryReader{ geo in
            let side = min(geo.size.width, geo.size.height)
            let logoSize = side * self.style.logoRatio
            ZStack{

                //封面外面的光晕,静态的,不用每一帧画
                Circle()
                    .fill(RadialGradient(colors: [(self.tint?.lightened(0.3).color(0.45) ?? Color(red: 110 / 255, green: 120 / 255, blue: 1).opacity(0.45)), .clear],
                                         center: .center, startRadius: logoSize * 0.4, endRadius: logoSize * 0.5 + side * 0.1))
                    .frame(width: logoSize + side * 0.2, height: logoSize + side * 0.2)
                TimelineView(.animation(paused: !self.isActive)){ timeline in
                    let _ = self.simulation.advance(to: timeline.date, isPlaying: self.isPlaying, style: self.style, shockwave: self.shockwave)
                    ZStack{
                        Canvas{ context, size in
                            let time = timeline.date.timeIntervalSinceReferenceDate
                            let palette = self.tint.map{ WavePalette.cover($0) } ?? WavePalette.standard(hueShift: sin(time * 0.25) * 0.5 + 0.5)
                            self.simulation.draw(in: &context, size: size, style: self.style, palette: palette)
                        }
                        MusicImage(self.logo)
                            .frame(width: logoSize, height: logoSize)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: side / 96))
                            .rotationEffect(.radians(self.simulation.rotation))
                    }
                }
                .frame(width: side, height: side)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: self.coverColor ? self.logo : nil){
            self.tint = self.coverColor ? await CoverColor.dominant(self.logo) : nil
        }
    }
}

/// 环形波形的物理效果:上升直接追随频谱,下降按重力加速,各样式的粒子、残影、冲击波
final class WaveSimulation: ObservableObject {

    /// 一个方向上的一根水柱(左右对称,只算一半)
    struct Bar {

        /// 当前高度(0到1)
        var height = WaveSimulation.MIN_HEIGHT

        /// 下落速度
        var velocity = 0.0

        /// 顶端水滴的高度
        var cap = WaveSimulation.MIN_HEIGHT

        /// 顶端水滴的下落速度
        var capVelocity = 0.0

        /// 顶端水滴还要停顿的时间(秒)
        var hold = 0.0
    }

    /// 甩出去的水珠(水柱、圆润)
    struct Drop {

        /// 角度(弧度)
        var angle: Double

        /// 离圆环的高度(和水柱高度同一个单位)
        var radius: Double

        /// 往外飞的速度,受重力影响会变成负数落回来
        var radialVelocity: Double

        /// 角度方向的速度
        var angularVelocity: Double

        /// 剩余时间(秒)
        var life: Double

        /// 大小的倍数
        var scale: Double
    }

    /// 往外喷的光点(粒子)
    struct Particle {

        /// 角度(弧度)
        let angle: Double

        /// 离圆环的距离(和波形高度同一个单位)
        var radius = 0.0

        /// 往外飞的速度,越来越慢
        var speed: Double

        /// 剩余亮度(1到0)
        var life = 1.0

        /// 大小的倍数
        let scale: Double

        /// 用调色板里的哪个颜色(0内圈 1中间 2外圈)
        let colorIndex: Int
    }

    /// 低音冲击波的一圈光环
    struct Shockwave {

        /// 扩散的距离(和波形高度同一个单位)
        var radius = 0.0

        /// 透明度,扩散时变淡
        var alpha = 0.9
    }

    /// 水柱的最低高度,暂停时落到这个高度
    static let MIN_HEIGHT = 0.04

    /// 顶部低音放大的倍数
    private static let LOW_BOOST = 1.0

    /// 高音压低的比例,最底部的高音只剩(1 - HIGH_CUT),越大高低音的反差越大
    private static let HIGH_CUT = 0.5

    /// 水柱下落的重力加速度,越大落得越快
    private static let GRAVITY = 3.2

    /// 顶端水滴下落的重力加速度
    private static let CAP_GRAVITY = 2.2

    /// 顶端水滴停顿的时间(秒)
    private static let CAP_HOLD = 0.14

    /// 同时最多的水珠数
    private static let MAX_DROPS = 60

    /// 同时最多的光点数
    private static let MAX_PARTICLES = 420

    /// 示波器保留的残影数
    static let SCOPE_TRAILS = 5

    /// 封面转一圈的时间(秒)
    private static let ROTATION_SECONDS = 30.0

    /// 极光三条光带各自的音量比例(低音、中音、高音)
    private static let AURORA_GAINS = [1.0, 0.85, 0.75]

    /// 极光三条光带的转动速度(弧度/秒),相邻两条反方向转
    private static let AURORA_SPEEDS = [0.05, -0.085, 0.12]

    private(set) var bars = [Bar]()
    private(set) var auroraLayers = [[Bar]]()
    private(set) var auroraAngles = [0.0, 0.0, 0.0]
    private(set) var drops = [Drop]()
    private(set) var particles = [Particle]()
    private(set) var shockwaves = [Shockwave]()

    /// 示波器当前和之前几帧的波形(-1到1),第一个是当前的
    private(set) var scopeHistory = [[Double]]()

    /// 示波器的振幅比例,暂停时慢慢变成0(波形变回一个圆)
    private(set) var scopeLevel = 0.0

    /// 最近的最大振幅,用来把不同响度的歌都放大到差不多的幅度
    private var scopePeak = 0.1

    /// 低音的平均强度和上一次冲击波的时间,判断鼓点
    private var bassAverage = 0.0
    private var lastShockTime = 0.0
    private var time = 0.0

    private var lastDate: Date?

    /// 封面转动的角度(弧度)
    private(set) var rotation = 0.0

    /// 前进到这一帧:按频谱更新各样式的状态,播放时封面转动
    func advance(to date: Date, isPlaying: Bool, style: PlayingWaveStyle, shockwave: Bool) {
        let dt = min(0.05, max(0, date.timeIntervalSince(self.lastDate ?? date)))
        self.lastDate = date
        if dt == 0{
            return
        }
        self.time += dt
        if isPlaying{
            self.rotation += dt * 2 * .pi / WaveSimulation.ROTATION_SECONDS
        }
        if style == .off{
            self.bars = []
            self.auroraLayers = []
            self.drops = []
            self.particles = []
            self.shockwaves = []
            self.scopeHistory = []
            return
        }
        let bands = isPlaying ? AudioSpectrum.shared.latestBands : []
        let half = style.pointCount / 2
        switch style {
        case .bars, .smooth, .mirror, .particles:
            self.stepBars(bands, half: half, dt: dt, withDrops: style == .bars || style == .smooth)
            if style == .particles{
                self.stepParticles(isPlaying: isPlaying, dt: dt)
            }
        case .aurora:
            self.stepAurora(bands, half: half, dt: dt, isPlaying: isPlaying)
        case .scope:
            self.stepScope(isPlaying ? AudioSpectrum.shared.latestWave : [], isPlaying: isPlaying, dt: dt)
        case .off:
            break
        }
        self.stepDrops(dt)
        self.stepShockwaves(bands, enabled: shockwave && isPlaying, dt: dt)
    }

    /// 水柱(水柱、圆润、镜像、粒子共用):顶部是低音,往下是高音
    private func stepBars(_ bands: [Float], half: Int, dt: Double, withDrops: Bool) {
        if self.bars.count != half + 1{
            self.bars = [Bar](repeating: Bar(), count: half + 1)
            self.drops = []
        }
        for k in 0 ... half{
            let target = WaveSimulation.target(k, half: half, bands: bands)
            if let height = WaveSimulation.step(&self.bars[k], target: target, dt: dt), withDrops{
                self.spawnDrop(k, half: half, height: height)
            }
        }
    }

    /// 极光:三条光带分别取低音、中音、高音三段频谱
    private func stepAurora(_ bands: [Float], half: Int, dt: Double, isPlaying: Bool) {
        if self.auroraLayers.count != 3 || self.auroraLayers[0].count != half + 1{
            self.auroraLayers = [[Bar]](repeating: [Bar](repeating: Bar(), count: half + 1), count: 3)
        }
        let third = AudioSpectrum.BAND_COUNT / 3
        for layer in 0 ..< 3{
            if isPlaying{
                self.auroraAngles[layer] += WaveSimulation.AURORA_SPEEDS[layer] * dt
            }
            for k in 0 ... half{
                var target = 0.05
                if !bands.isEmpty{
                    let index = min(bands.count - 1, layer * third + Int(Double(k) / Double(half) * Double(third - 1)))
                    target = max(0.05, Double(bands[index]) * WaveSimulation.AURORA_GAINS[layer])
                }
                _ = WaveSimulation.step(&self.auroraLayers[layer][k], target: target, dt: dt)
            }
        }
    }

    /// 粒子:每个方向按水柱高度的平方随机喷出光点,飞出去之后减速、变淡
    private func stepParticles(isPlaying: Bool, dt: Double) {
        if isPlaying{
            let count = (self.bars.count - 1) * 2
            for i in 0 ..< count where self.particles.count < WaveSimulation.MAX_PARTICLES{
                let h = self.bars[min(self.bars.count - 1, i <= count / 2 ? i : count - i)].height
                if Double.random(in: 0 ..< 1) < h * h * 1.4 * dt * 30{
                    let angle = Double(i) / Double(count) * 2 * .pi - .pi / 2 + Double.random(in: -0.02 ... 0.02)
                    self.particles.append(Particle(angle: angle, speed: (0.6 + h * 1.6) * Double.random(in: 0.6 ... 1.2),
                                                   scale: Double.random(in: 0.5 ... 1.7), colorIndex: Int.random(in: 0 ... 2)))
                }
            }
        }
        let drag = pow(0.18, dt)
        for i in self.particles.indices{
            self.particles[i].radius += self.particles[i].speed * dt
            self.particles[i].speed *= drag
            self.particles[i].life -= dt * (0.55 + 0.25 * self.particles[i].scale)
        }
        self.particles.removeAll{ $0.life <= 0 || $0.radius > 1.2 }
    }

    /// 示波器:按最近的最大振幅放大,平滑掉太细的抖动,保留几帧作为残影
    private func stepScope(_ wave: [Float], isPlaying: Bool, dt: Double) {
        self.scopeLevel += ((isPlaying ? 1 : 0) - self.scopeLevel) * min(1, dt * 4)
        var values = wave.map{ Double($0) }
        if values.isEmpty{
            values = self.scopeHistory.first ?? [Double](repeating: 0, count: AudioSpectrum.WAVE_COUNT)
        } else {
            let peak = values.map{ abs($0) }.max() ?? 0
            self.scopePeak = max(0.08, max(peak, self.scopePeak * pow(0.5, dt)))
            values = values.map{ $0 / self.scopePeak }
            for _ in 0 ..< 2{
                let n = values.count
                values = values.indices.map{ (values[max(0, $0 - 1)] + 2 * values[$0] + values[min(n - 1, $0 + 1)]) / 4 }
            }
        }
        self.scopeHistory.insert(values, at: 0)
        if self.scopeHistory.count > WaveSimulation.SCOPE_TRAILS{
            self.scopeHistory.removeLast()
        }
    }

    /// 甩出去的水珠受重力落回圆环
    private func stepDrops(_ dt: Double) {
        for i in self.drops.indices{
            self.drops[i].radialVelocity -= WaveSimulation.GRAVITY * 0.9 * dt
            self.drops[i].radius += self.drops[i].radialVelocity * dt
            self.drops[i].angle += self.drops[i].angularVelocity * dt
            self.drops[i].life -= dt
        }
        self.drops.removeAll{ $0.radius <= 0 || $0.life <= 0 }
    }

    /// 低音冲击波:低音明显比平时强(鼓点)时放出一圈光环,往外扩散并变淡;两圈之间至少隔0.32秒
    private func stepShockwaves(_ bands: [Float], enabled: Bool, dt: Double) {
        if enabled && bands.count >= 6{
            let bass = Double(bands[0 ..< 6].reduce(0, +)) / 6
            if bass > 0.42 && bass > self.bassAverage * 1.12 && self.time - self.lastShockTime > 0.32{
                self.shockwaves.append(Shockwave())
                self.lastShockTime = self.time
            }
            self.bassAverage = self.bassAverage * 0.85 + bass * 0.15
        }
        for i in self.shockwaves.indices{
            self.shockwaves[i].radius += dt * 0.9
            self.shockwaves[i].alpha -= dt * 0.9
        }
        self.shockwaves.removeAll{ $0.alpha <= 0 }
    }

    /// 水柱的目标高度:从频谱里取对应的频段,顶部是低音,往下是高音;没有频谱(暂停)时落到最低
    private static func target(_ k: Int, half: Int, bands: [Float]) -> Double {
        guard !bands.isEmpty else{
            return WaveSimulation.MIN_HEIGHT
        }
        let f = Double(k) / Double(half)
        let value = Double(bands[min(bands.count - 1, Int(f * Double(bands.count - 1)))])

        //顶部的低音放大(最多LOW_BOOST倍,往下很快减弱),高音的柱子低一些
        let lowBoost = 1 + (WaveSimulation.LOW_BOOST - 1) * pow(1 - f, 3)
        return min(1, max(WaveSimulation.MIN_HEIGHT, value * (1 - WaveSimulation.HIGH_CUT * f) * lowBoost))
    }

    /// 一根水柱:比目标低时快速冲高,比目标高时受重力加速落下;顶端水滴停一下再落
    /// - Returns: 落得快的高柱子返回下落之前的高度,可以甩出水珠
    private static func step(_ bar: inout Bar, target: Double, dt: Double) -> Double? {
        var dropHeight: Double?
        if target > bar.height{
            bar.height += (target - bar.height) * min(1, dt * 28)
            bar.velocity = 0
        } else {
            let previous = bar.height
            bar.velocity += WaveSimulation.GRAVITY * dt
            bar.height = max(target, bar.height - bar.velocity * dt)
            if bar.velocity > 1.1 && previous > 0.5 && Double.random(in: 0 ..< 1) < 0.18{
                dropHeight = previous
            }
        }
        if bar.height >= bar.cap{
            bar.cap = bar.height
            bar.capVelocity = 0
            bar.hold = WaveSimulation.CAP_HOLD
        } else if bar.hold > 0{
            bar.hold -= dt
        } else {
            bar.capVelocity += WaveSimulation.CAP_GRAVITY * dt
            bar.cap = max(bar.height, bar.cap - bar.capVelocity * dt)
        }
        return dropHeight
    }

    /// 从一根水柱的顶端左右各甩出一颗水珠
    private func spawnDrop(_ k: Int, half: Int, height: Double) {
        if self.drops.count > WaveSimulation.MAX_DROPS{
            return
        }
        let count = half * 2
        for side in [1, -1]{
            if side < 0 && (k == 0 || k == half){
                continue
            }
            let i = side > 0 ? k : count - k
            self.drops.append(Drop(angle: Double(i) / Double(count) * 2 * .pi - .pi / 2 + Double.random(in: -0.015 ... 0.015),
                                   radius: height,
                                   radialVelocity: 0.35 + Double.random(in: 0 ..< 0.5),
                                   angularVelocity: Double.random(in: -0.125 ... 0.125),
                                   life: 1.6,
                                   scale: 0.6 + Double.random(in: 0 ..< 0.8)))
        }
    }

    /// 第i个点对应的水柱(左右对称)
    func barIndex(_ i: Int, _ count: Int, barCount: Int) -> Int {
        let half = count / 2
        return min(barCount - 1, i <= half ? i : count - i)
    }
}
