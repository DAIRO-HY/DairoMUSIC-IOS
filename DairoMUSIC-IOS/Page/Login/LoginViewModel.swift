//
//  LoginViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

/// 服务器页面和登录页面共用
class LoginViewModel: ObservableObject {

    /// 服务器地址,在服务器页面输入,登录页面只显示
    @Published var domain: String

    /// 登录账号:邮箱或用户名
    @Published var account: String

    /// 密码
    @Published var pwd = ""

    /// 服务器是否开放注册,关闭时隐藏注册和免注册使用,还没有获取到时为nil
    @Published var allowRegister: Bool?

    /// 从服务器页面跳转到登录页面
    @Published var showLogin = false

    //编辑模式时,当前账号所在的索引
    var editLoggedIndex: Int?

    init(domain: String = "", account: String = "", editLoggedIndex: Int? = nil) {
        self.domain = domain
        self.account = account
        self.editLoggedIndex = editLoggedIndex
    }

    /// 服务器页面下一步点击事件,确认是DairoMUSIC服务器之后跳转到登录页面
    func onNextClick(){
        var domain = self.domain.trim()
        if domain.isEmpty {
            Toast.show("请输入服务器地址")
            return
        }
        if !domain.hasPrefix("http://") && !domain.hasPrefix("https://") {

            //补全url
            domain = "http://" + domain
        }
        while domain.hasSuffix("/") {

            //去掉最后的/
            domain.removeLast()
        }
        SettingShared.checkServer(domain: domain){ config in
            self.domain = domain
            self.allowRegister = config.allowRegister
            self.showLogin = true
        }
    }

    /// 直接打开登录页面时(登录失效、编辑账号),获取服务器是否开放注册
    func loadConfig(){
        if self.allowRegister != nil || self.domain.isEmpty{
            return
        }
        CommonApi.config().domain(self.domain).hide().fail{ _ in
        }.error{ _ in
        }.send{
            self.allowRegister = $0.allowRegister
        }
    }

    /// 登录按钮点击事件
    func onLoginClick(){
        let account = self.account.trim()
        if account.isEmpty {
            Toast.show("请输入邮箱或用户名")
            return
        }
        let pwd = self.pwd
        if pwd.isEmpty {
            Toast.show("密码必填")
            return
        }
        SettingShared.login(domain: self.domain, editIndex: self.editLoggedIndex, request: {
            UserApi.login(account: account, pwd: pwd)
        }, success: {
            DiscoverPage().relaunch()
        })
    }

    /// 免注册使用点击事件,同一台设备再次使用时找回同一个临时会员
    func onTempLoginClick(){
        SettingShared.login(domain: self.domain, editIndex: self.editLoggedIndex, request: {
            UserApi.tempLogin()
        }, success: {
            DiscoverPage().relaunch()
        })
    }
}
