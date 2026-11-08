//
//  AppDelegate.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/08.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    /// iPad支持所有方向,iPhone只支持竖屏,视频全屏播放时切换到横屏
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if OrientationUtil.isPad{
            return .all
        }
        return OrientationUtil.mask
    }
}
