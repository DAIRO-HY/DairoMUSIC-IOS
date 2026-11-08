//
//  UIImage++.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import UIKit

extension UIImage {

    /// 缩小图片并转换成jpg,用于上传头像和封面
    /// - Parameter maxSize: 最大边长
    func toJpeg(maxSize: CGFloat) -> Data? {
        let scale = min(1, maxSize / max(self.size.width, self.size.height))
        let size = CGSize(width: self.size.width * scale, height: self.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.9){ _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
