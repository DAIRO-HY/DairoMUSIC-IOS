//
//  DairoMusicApp.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

@main
struct DairoMusicApp: App {

    //视频全屏时允许横屏
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    //App前后台状态
    @Environment(\.scenePhase) private var scenePhase

    init(){

        //提前创建SDK实例
        _ = try? FileSdkUtil.get()

        //开始监听网络类型,切换歌曲时判断离线模式
        _ = NetworkMonitor.shared

        //恢复上次的播放列表,不自动播放
        PlayerManager.shared.restore()

        //提交上次没有提交成功的播放记录,网络恢复时再提交
        PlayCountUtil.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView{
                if SettingShared.isLogin{
                    DiscoverPage()
                }else{
                    ServerPage()
                }
            }
        }
        .onChange(of: self.scenePhase) { phase in
            switch phase {
            case .active:
                FileSdkUtil.checkServer()
                ServerConfig.shared.load()

                //VIP状态可能变化了(到期、兑换、后台修改)
                if SettingShared.isLogin{
                    SettingShared.loadUserInBackground(silent: true)
                }
            case .background:
                PlayerManager.shared.savePlayingInfo()
                FileSdkUtil.flush()
            default:
                break
            }
        }
    }
}
