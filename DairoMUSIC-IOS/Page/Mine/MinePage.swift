//
//  MinePage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoFileSDK
import DairoUI_IOS

struct MinePage: View {

    ///主题选择数据
    private let themeData = [SettingPickerData("跟随系统",0),SettingPickerData("明亮模式",1),SettingPickerData("黑暗模式",2)]

    ///音质选择数据
    private let bitRateData = [
        SettingPickerData("标准(128K)",128),
        SettingPickerData("超高品质(320K)",320),
        SettingPickerData("无损",SettingShared.BIT_RATE_LOSSLESS)
    ]

    //视图模型
    @StateObject private var vm = MineViewModel()

    //主题设置值
    @AppStorage("theme") private var theme = 0

    /// 定时停止播放
    @ObservedObject private var sleepTimer = SleepTimer.shared

    /// 显示自定义停止时间的选择
    @State private var showSleepTimeCustom = false

    /// 选择自定义之前的定时时长,取消选择时恢复
    @State private var sleepMinutesBeforeCustom = 0

    /// 显示退出登录确认框
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationView{
            SettingStack(embedInNavigationStack: false){
                SettingPage(verticalPadding: 16){
                    SettingGroup{
                        SettingCustomView{
                            NavigationLink(destination: LoggedPage()){
                                self.topLogoView
                            }
                            .buttonStyle(.row)
                        }
                    }
                    SettingGroup{
                        SettingNavigationLink("个人资料",tip: self.vm.user?.isTemp == true ? "未绑定邮箱" : "昵称、头像"){
                            ProfilePage().anyView
                        }.icon("person.crop.circle.fill", backgroundColor: Color.blue)
                        if self.vm.user?.isTemp == false{
                            SettingNavigationLink("修改密码"){
                                ModifyPwdPage().anyView
                            }.icon("lock.rotation", backgroundColor: Color.orange)
                        }
                    }
                    SettingGroup(footer: self.sleepTimerFooter){
                        SettingPicker("定时停止播放", data: SleepTimer.OPTIONS, value: self.$sleepTimer.minutes){
                            if $0 == SleepTimer.CUSTOM{

                                //选项页面返回之后再弹出时间选择
                                self.sleepMinutesBeforeCustom = self.sleepTimer.minutes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
                                    self.showSleepTimeCustom = true
                                }
                                return true
                            }
                            self.sleepTimer.start(minutes: $0)
                            return true
                        }
                        .icon("moon.zzz.fill", backgroundColor: Color.purple)
                        if self.sleepTimer.endDate != nil{
                            SettingToggle(title: "播完整首歌再停止", isOn: self.$sleepTimer.isWaitSongEnd)
                        }
                    }
                    SettingGroup{
                        SettingPicker("播放音质",data: self.bitRateData, value: self.$vm.bitRate, changeFunc: self.vm.onBitRateChange)
                            .icon("waveform", backgroundColor: Color.theme)
                        SettingNavigationLink("缓存管理",tip: "歌曲、视频和图片缓存"){
                            CachePage().anyView
                        }.icon("internaldrive.fill", backgroundColor: Color.indigo)
                        SettingPicker("切换主题",data: self.themeData, value: self.$theme)
                            .icon("paintbrush.fill", backgroundColor: Color.red)
                    }
                    SettingGroup{
                        SettingNavigationLink("意见反馈"){
                            FeedbackPage().anyView
                        }.icon("square.and.pencil", backgroundColor: Color.green)
                        SettingNavigationLink("关于"){
                            AboutPage().anyView
                        }.icon("info.circle.fill", backgroundColor: Color.gray)

                        //临时调试入口:排查后台放久之后本机HTTP服务失效的问题,找到原因之后删除
                        //if let sdk = try? FileSdkUtil.get(){
                        //    SettingNavigationLink("SDK调试"){
                        //        FileSdkDebugView(sdk: sdk).anyView
                        //    }.icon("ladybug.fill", backgroundColor: Color.gray)
                        //}
                    }
                    SettingGroup{
                        SettingButtonSingle("退出登录"){
                            self.showLogoutAlert = true
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0){
                HomeTabView(.MINE_PAGE)
            }
            .navigationTitle("我的")
            .navigationBarHidden(true)
            .onAppear(perform: self.vm.loadUser)
            .sheet(isPresented: self.$showSleepTimeCustom){
                SleepTimeCustomPage{ time in
                    if let time{
                        self.sleepTimer.start(until: time)
                    } else {
                        self.sleepTimer.minutes = self.sleepMinutesBeforeCustom
                    }
                }
                .presentationDetents([.medium])
            }
            .alert("确定退出登录吗？", isPresented: self.$showLogoutAlert){
                Button("退出", role: .destructive, action: self.vm.onLogoutClick)
                Button("取消", role: .cancel){}
            }
        }
        //iPad上默认是左右分栏,这里要全屏显示
        .navigationViewStyle(.stack)
    }

    /// 定时停止播放的说明
    private var sleepTimerFooter: String? {
        if self.sleepTimer.isWaitingSongEnd{
            return "定时时间已到,当前歌曲播放结束之后停止"
        }
        guard let endDate = self.sleepTimer.endDate else{
            return nil
        }
        return "将在" + SleepTimeCustomPage.format(endDate) + "停止播放"
    }

    /// 顶部头像部分视图
    private var topLogoView: some View {
        HStack {
            UserAvatar(self.vm.user?.logo, size: 50)
            VStack(alignment: .leading, spacing: 2){
                HStack(spacing: 4){
                    Text(self.vm.displayName)
                        .foregroundColor(.primary)
                        .font(.title3)
                        .lineLimit(1)
                    if self.vm.user?.isTemp == true && self.vm.displayName != "临时会员"{
                        Text("临时会员").font(.caption2).foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary, lineWidth: 0.5))
                    }
                }
                Text(self.vm.logged?.domain ?? "")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 6)
            Image(systemName: "chevron.forward").foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    MinePage()
}
