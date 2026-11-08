//
//  OrientationUtil.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/08.
//

import UIKit

/// 屏幕方向控制,iPhone上只支持竖屏,视频全屏播放时切换到横屏;iPad支持所有方向
enum OrientationUtil {

    /// iPhone当前允许的方向
    static private(set) var mask = UIInterfaceOrientationMask.portrait

    /// 是否是iPad
    static var isPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    /// 切换iPhone的屏幕方向,iPad不处理
    /// - Parameter landscape: true:横屏 false:竖屏
    static func rotate(landscape: Bool) {
        if OrientationUtil.isPad{
            return
        }
        OrientationUtil.mask = landscape ? .landscape : .portrait
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else{
            return
        }

        //通知所有页面重新获取支持的方向
        var vc = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let current = vc{
            current.setNeedsUpdateOfSupportedInterfaceOrientations()
            vc = current.presentedViewController
        }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: OrientationUtil.mask))
    }
}
