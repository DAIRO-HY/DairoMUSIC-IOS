//
//  Const.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import UIKit

///静态变量配置
enum Const {

    ///客户端标识 0:WEB 1:Android 2:IOS 3:Windows 4:Mac 5:Linux
    static let CLIENT_FLAG = 2

    ///服务器默认端口
    static let DEFAULT_PORT = 8020

    ///获取设备唯一标识
    static var deviceId: String {
        let uuid = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        return uuid.md5
    }

    ///整数版本号
    static var versionCode: Int {
        return Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "") ?? 0
    }

    ///版本名
    static var versionName: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
