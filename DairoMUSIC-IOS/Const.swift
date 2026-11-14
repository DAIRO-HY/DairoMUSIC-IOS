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

    ///服务器端的GitHub项目地址
    static let SERVER_GITHUB_URL = "https://github.com/DAIRO-HY/DairoMUSIC"

    ///设备标识保存在钥匙串里的名字
    static let KEY_DEVICE_ID = "DEVICE_ID"

    private static var mDeviceId: String?

    ///设备唯一标识,免注册使用时用来找回同一个临时会员
    ///保存在钥匙串里,卸载重装之后不变;第一次生成时沿用以前用identifierForVendor生成的标识,升级之前的临时会员也能找回
    static var deviceId: String {
        if let deviceId = Const.mDeviceId{
            return deviceId
        }
        if let deviceId = KeychainUtil.read(Const.KEY_DEVICE_ID){
            Const.mDeviceId = deviceId
            return deviceId
        }
        let deviceId = (UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString).md5
        KeychainUtil.write(deviceId, Const.KEY_DEVICE_ID)
        Const.mDeviceId = deviceId
        return deviceId
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
