//
//  CoverColor.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/19.
//

import UIKit

/// 从封面取主色,波形颜色跟随封面时用
@MainActor
enum CoverColor {

    /// 取过的封面,换歌回来不用再算
    private static var cache = [String: WaveColor]()

    /// 缩小到多大再取色
    private static let SAMPLE_SIZE = 24

    /// 取最鲜艳、最亮的多少个像素的平均色
    private static let TOP_COUNT = 40

    /// 封面的主色:缩小之后取最鲜艳、最亮的那些像素的平均色,再提亮到最亮的分量为1,在深色背景上看得清
    static func dominant(_ url: String?) async -> WaveColor? {
        guard let url, !url.isEmpty else{
            return nil
        }
        if let color = CoverColor.cache[url]{
            return color
        }
        guard let data = await FileSdkUtil.imageData(url), let image = UIImage(data: data)?.cgImage,
              let color = CoverColor.compute(image) else{
            return nil
        }
        CoverColor.cache[url] = color
        return color
    }

    /// 计算主色
    private static func compute(_ image: CGImage) -> WaveColor? {
        let size = CoverColor.SAMPLE_SIZE
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        guard let context = CGContext(data: &pixels, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else{
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        var candidates = [(score: Double, r: Double, g: Double, b: Double)]()
        for i in stride(from: 0, to: pixels.count, by: 4){
            let r = Double(pixels[i]) / 255, g = Double(pixels[i + 1]) / 255, b = Double(pixels[i + 2]) / 255
            let maxValue = max(r, g, b), minValue = min(r, g, b)
            let saturation = maxValue > 0 ? (maxValue - minValue) / maxValue : 0
            candidates.append((saturation * maxValue, r, g, b))
        }
        let top = candidates.sorted{ $0.score > $1.score }.prefix(CoverColor.TOP_COUNT)
        guard !top.isEmpty else{
            return nil
        }
        let count = Double(top.count)
        let r = top.map{ $0.r }.reduce(0, +) / count
        let g = top.map{ $0.g }.reduce(0, +) / count
        let b = top.map{ $0.b }.reduce(0, +) / count
        let brightest = max(r, g, b, 0.01)
        return WaveColor(red: r / brightest, green: g / brightest, blue: b / brightest)
    }
}
