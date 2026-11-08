//
//  DownloadListViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/08.
//

import SwiftUI
import DairoFileSDK
import DairoUI_IOS

/// 下载的类型
enum DownloadType {

    /// 歌曲
    case music

    /// 视频
    case video

    /// SDK的分组
    var group: String {
        return self == .music ? FileSdkUtil.GROUP_MUSIC : FileSdkUtil.GROUP_VIDEO
    }

    /// 页面标题
    var title: String {
        return self == .music ? "已下载的歌曲" : "已下载的视频"
    }

    /// 没有下载时的提示
    var emptyText: String {
        return self == .music ? "没有下载的歌曲" : "没有下载的视频"
    }

    /// 全部删除的确认框标题
    var deleteAllTitle: String {
        return self == .music ? "确定删除全部已下载的歌曲吗？" : "确定删除全部已下载的视频吗？"
    }
}

class DownloadListViewModel: ObservableObject {

    /// 刷新下载进度的间隔(秒)
    private static let REFRESH_SECONDS = 1.0

    let type: DownloadType

    /// 下载列表,最近添加的在前面
    @Published private(set) var items = [CacheInfo]()

    /// 定时刷新下载进度
    private var timer: Timer?

    init(_ type: DownloadType) {
        self.type = type
    }

    /// 页面显示时开始定时刷新
    func start() {
        self.refresh()
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: DownloadListViewModel.REFRESH_SECONDS, repeats: true){ [weak self] _ in
            self?.refresh()
        }
    }

    /// 页面关闭时停止刷新
    func stop() {
        self.timer?.invalidate()
        self.timer = nil
    }

    /// 从SDK读取下载列表,读数据库不在主线程
    private func refresh() {
        let group = self.type.group
        DispatchQueue.global().async {
            let items = FileSdkUtil.downloads(group: group)
            DispatchQueue.main.async {
                if items != self.items{
                    self.items = items
                }
            }
        }
    }

    /// 暂停、继续、重试
    func onStateClick(_ info: CacheInfo) {
        switch info.state{
        case .downloading, .waiting:
            FileSdkUtil.pause(ids: [info.id])
        case .paused, .error:
            FileSdkUtil.resume(ids: [info.id])
        case .finish:
            break
        }
        self.refresh()
    }

    /// 删除选中的
    func delete(_ ids: [String]) {
        let idSet = Set(ids)
        self.items.removeAll{ idSet.contains($0.id) }
        DispatchQueue.global().async {
            FileSdkUtil.delete(ids: ids)
        }
    }

    /// 全部删除
    func deleteAll() {
        let ids = self.items.map{ $0.id }
        self.items = []
        Loading.show()
        DispatchQueue.global().async {
            FileSdkUtil.delete(ids: ids)
            DispatchQueue.main.async {
                Loading.hide()
                Toast.show("已删除")
                self.refresh()
            }
        }
    }
}
