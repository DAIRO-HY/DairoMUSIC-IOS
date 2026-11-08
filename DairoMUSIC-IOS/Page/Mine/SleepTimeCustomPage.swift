//
//  SleepTimeCustomPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/09.
//

import SwiftUI

/// 自定义定时停止播放的时间,选择时和分,比现在早时为明天的这个时间
struct SleepTimeCustomPage: View {

    /// 选择结束,确定时返回选择的时间,取消时返回nil
    let onFinish: (_ time: Date?) -> Void

    /// 选择的时间,默认30分钟之后
    @State private var time = Date().addingTimeInterval(30 * 60)

    /// 是否已经回调过,下拉关闭页面时当作取消
    @State private var isFinished = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView{
            VStack(spacing: 12){
                DatePicker("停止时间", selection: self.$time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                Text(self.tip)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("自定义停止时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement: .cancellationAction){
                    Button("取消"){
                        self.finish(nil)
                    }
                }
                ToolbarItem(placement: .confirmationAction){
                    Button("确定"){
                        self.finish(self.time)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onDisappear{
            if !self.isFinished{
                self.isFinished = true
                self.onFinish(nil)
            }
        }
    }

    /// 停止时间的说明,明天的时间加上"明天"
    private var tip: String {
        let endDate = SleepTimer.nextDate(self.time)
        let minutes = Int(endDate.timeIntervalSinceNow / 60) + 1
        let duration = minutes >= 60 ? "\(minutes / 60)小时\(minutes % 60)分钟" : "\(minutes)分钟"
        return SleepTimeCustomPage.format(endDate) + "停止播放,大约" + duration + "之后"
    }

    /// 确定或取消
    private func finish(_ time: Date?) {
        self.isFinished = true
        self.onFinish(time)
        self.dismiss()
    }

    /// 格式化停止时间,不是今天时加上"明天"
    static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let prefix = Calendar.current.isDateInToday(date) ? "" : "明天"
        return prefix + formatter.string(from: date)
    }
}

#Preview {
    SleepTimeCustomPage{ _ in }
}
