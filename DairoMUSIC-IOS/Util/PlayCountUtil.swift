//
//  PlayCountUtil.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/14.
//

import Foundation
import DairoUI_IOS

/**
 播放次数:歌曲自然播放到结尾时先记录到本地的待提交记录,再提交到服务器,在线和离线播放用同一套逻辑
 待提交记录按账号保存到磁盘,退出App不会丢;提交成功之后删除已经提交的部分,失败时保留
 下一次播放完成、网络恢复、App启动、切换账号时再提交
 只在主线程调用
 */
enum PlayCountUtil {

    /// 待提交记录的本地缓存名,内容是歌曲ID,播放了几次就有几个
    private static let _KEY_PENDING = "play_count_pending"

    /// 一次最多提交的记录数
    private static let MAX_BATCH = 500

    /// 正在提交的记录文件名,同一个账号的记录不会同时提交两次
    nonisolated(unsafe) private static var submitting = Set<String>()

    /// 网络恢复的监听
    nonisolated(unsafe) private static var networkObserver: NSObjectProtocol?

    /// App启动时调用:开始监听网络恢复,提交上次没有提交成功的记录
    static func start() {
        if PlayCountUtil.networkObserver == nil{
            PlayCountUtil.networkObserver = NotificationCenter.default.addObserver(forName: NetworkMonitor.AVAILABLE, object: nil, queue: .main){ _ in
                PlayCountUtil.submit()
            }
        }
        PlayCountUtil.submit()
    }

    /// 歌曲播放完成,记录一次并提交;采集平台的搜索结果(还没有加入曲库)不计
    static func add(_ music: MusicModel) {
        guard music.id > 0, let name = SettingShared.accountObjectName(PlayCountUtil._KEY_PENDING) else{
            return
        }
        var ids = PlayCountUtil.read(name)
        ids.append(music.id)
        _ = LocalObjectUtil.write(ids, name)
        PlayCountUtil.submit()
    }

    /// 提交当前账号的待提交记录,超过500条时分批提交
    static func submit() {
        guard let name = SettingShared.accountObjectName(PlayCountUtil._KEY_PENDING), !PlayCountUtil.submitting.contains(name) else{
            return
        }
        let batch = Array(PlayCountUtil.read(name).prefix(PlayCountUtil.MAX_BATCH))
        if batch.isEmpty{
            return
        }
        PlayCountUtil.submitting.insert(name)
        MusicApi.play(ids: batch.map{ String($0) }.joined(separator: ",")).hide().fail{ _ in
            PlayCountUtil.submitting.remove(name)
        }.error{ _ in
            PlayCountUtil.submitting.remove(name)
        }.send{
            PlayCountUtil.submitting.remove(name)

            //提交过程中新增的记录追加在后面,只删除已经提交的部分
            let ids = PlayCountUtil.read(name)
            _ = LocalObjectUtil.write(Array(ids.dropFirst(batch.count)), name)

            //还有没提交的继续提交下一批
            PlayCountUtil.submit()
        }
    }

    /// 读取待提交记录
    private static func read(_ name: String) -> [Int64] {
        return LocalObjectUtil.read([Int64].self, name) ?? []
    }
}
