//
//  NetworkMonitor.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/10.
//

import Foundation
import Network

/// 网络类型
enum NetworkType {

    /// 还没有获取到网络状态
    case unknown

    /// 没有网络
    case none

    /// WiFi
    case wifi

    /// 数据流量
    case cellular

    /// 其他(有线网络等)
    case other
}

/// 当前的网络类型,App启动时开始监听,只记录最新的状态,切换歌曲前读取
final class NetworkMonitor {

    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()

    /// 最新的网络状态,在监听线程里更新
    private var path: NWPath?

    private let lock = NSLock()

    private init() {
        self.monitor.pathUpdateHandler = { [weak self] path in
            self?.lock.lock()
            self?.path = path
            self?.lock.unlock()
        }
        self.monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }

    /// 当前的网络类型
    var current: NetworkType {
        self.lock.lock()
        let path = self.path
        self.lock.unlock()
        guard let path else{
            return .unknown
        }
        if path.status != .satisfied{
            return .none
        }
        if path.usesInterfaceType(.wifi){
            return .wifi
        }
        if path.usesInterfaceType(.cellular){
            return .cellular
        }
        return .other
    }
}
