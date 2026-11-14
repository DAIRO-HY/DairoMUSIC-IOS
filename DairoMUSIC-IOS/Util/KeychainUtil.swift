//
//  KeychainUtil.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/14.
//

import Foundation
import Security

/// 钥匙串存取,用来保存登录票据、设备标识等不能明文保存的数据
/// 只在本机有效,不会通过备份迁移到其他设备;设备开机第一次解锁之后就可以读取,锁屏时后台播放也要请求接口
/// 钥匙串里的数据卸载App之后依然保留
enum KeychainUtil {

    /// 所有数据都保存在这个服务名下
    private static let SERVICE = Bundle.main.bundleIdentifier ?? "cn.dairo.music"

    /// 读取
    static func read(_ key: String) -> String? {
        var query = KeychainUtil.query(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else{
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// 保存,已经存在时覆盖
    /// - Returns: 是否保存成功
    @discardableResult
    static func write(_ value: String, _ key: String) -> Bool {
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(KeychainUtil.query(key) as CFDictionary, attributes as CFDictionary)
        if status != errSecItemNotFound{
            return status == errSecSuccess
        }
        let query = KeychainUtil.query(key).merging(attributes){ $1 }
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    /// 删除
    static func delete(_ key: String) {
        SecItemDelete(KeychainUtil.query(key) as CFDictionary)
    }

    /// 删除所有数据,保留指定的项
    static func deleteAll(except keys: [String]) {
        let keep = keys.compactMap{ key in KeychainUtil.read(key).map{ (key, $0) } }
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainUtil.SERVICE
        ] as CFDictionary)
        keep.forEach{ KeychainUtil.write($0.1, $0.0) }
    }

    /// 查找一项数据的条件
    private static func query(_ key: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainUtil.SERVICE,
            kSecAttrAccount as String: key
        ]
    }
}
