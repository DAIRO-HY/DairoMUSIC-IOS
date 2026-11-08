//
//  SleepTimer.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/08.
//

import Foundation
import DairoUI_IOS

/**
 定时停止播放
 到时间之后暂停音乐和视频;开启"播完整首歌再停止"时,等当前歌曲播放结束再停止
 后台播放音乐时App不会被挂起,计时器可以正常触发
 */
class SleepTimer: ObservableObject {

    static let shared = SleepTimer()

    /// 自定义停止时间的选项值
    static let CUSTOM = -1

    /// 定时时长的选项(分钟),0表示不开启,-1表示自定义停止时间
    static let OPTIONS = [
        SettingPickerData("不开启", 0),
        SettingPickerData("15分钟", 15),
        SettingPickerData("30分钟", 30),
        SettingPickerData("45分钟", 45),
        SettingPickerData("60分钟", 60),
        SettingPickerData("90分钟", 90),
        SettingPickerData("自定义", SleepTimer.CUSTOM)
    ]

    /// 定时时长(分钟),0表示没有开启,-1表示自定义停止时间
    @Published var minutes = 0

    /// 停止播放的时间,没有开启时为nil
    @Published private(set) var endDate: Date?

    /// 是否等当前歌曲播放结束再停止
    @Published var isWaitSongEnd = false

    /// 时间已经到了,正在等当前歌曲播放结束
    @Published private(set) var isWaitingSongEnd = false

    /// 计时器
    private var timer: Timer?

    private init() {
    }

    /// 修改定时时长,重新开始计时
    /// - Parameter minutes: 定时时长(分钟),0表示取消
    func start(minutes: Int) {
        if minutes <= 0{
            self.schedule(nil, minutes: 0)
            return
        }
        self.schedule(Date().addingTimeInterval(TimeInterval(minutes * 60)), minutes: minutes)
    }

    /// 自定义停止时间,只用时和分,比现在早时为明天的这个时间
    func start(until time: Date) {
        self.schedule(SleepTimer.nextDate(time), minutes: SleepTimer.CUSTOM)
    }

    /// 时和分对应的下一个时间,比现在早(或相同)时为明天
    static func nextDate(_ time: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) ?? time
    }

    /// 开始计时
    /// - Parameter endDate: 停止播放的时间,为nil时取消定时
    private func schedule(_ endDate: Date?, minutes: Int) {
        self.timer?.invalidate()
        self.timer = nil
        self.minutes = minutes
        self.isWaitingSongEnd = false
        self.endDate = endDate
        guard let endDate else{
            return
        }
        let timer = Timer(fire: endDate, interval: 0, repeats: false){ [weak self] _ in
            self?.onTimeUp()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// 取消定时
    func cancel() {
        self.start(minutes: 0)
    }

    /// 歌曲播放结束时调用,正在等歌曲播放结束时返回true,这时停止播放并结束定时
    func consumeSongEnd() -> Bool {
        if !self.isWaitingSongEnd{
            return false
        }
        self.finish()
        return true
    }

    /// 时间到了
    private func onTimeUp() {
        self.timer = nil

        //音乐正在播放并且要等歌曲播放结束
        if self.isWaitSongEnd && PlayerManager.shared.isPlaying{
            self.isWaitingSongEnd = true
            return
        }
        PlayerManager.shared.pause()
        self.finish()
    }

    /// 定时结束,通知视频暂停
    private func finish() {
        self.minutes = 0
        self.endDate = nil
        self.isWaitingSongEnd = false
        NotificationCenter.default.post(name: EventName.SLEEP_TIMER_END, object: nil)
        Toast.show("定时时间到,已停止播放")
    }
}
