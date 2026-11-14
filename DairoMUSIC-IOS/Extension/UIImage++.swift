//
//  UIImage++.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import UIKit

extension UIImage {

    /// 转换成jpg原图,用于上传头像和封面;服务器会裁切、缩小,这里不缩小
    /// 服务器不一定处理jpg里的方向信息,方向不是正向时(相机拍的照片)重新画成正向
    func toUploadJpeg() -> Data? {
        if self.imageOrientation == .up{
            return self.jpegData(compressionQuality: 0.9)
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = self.scale
        return UIGraphicsImageRenderer(size: self.size, format: format).jpegData(withCompressionQuality: 0.9){ _ in
            self.draw(in: CGRect(origin: .zero, size: self.size))
        }
    }
}
