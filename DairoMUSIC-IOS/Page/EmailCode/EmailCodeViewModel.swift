//
//  EmailCodeViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

/// 需要邮箱验证码的操作
enum EmailCodeType: String {

    /// 注册
    case register = "register"

    /// 重置密码
    case resetPwd = "reset_pwd"

    /// 临时会员绑定邮箱
    case bindEmail = "bind_email"

    /// 页面标题
    var title: String {
        switch self {
        case .register:
            return "注册"
        case .resetPwd:
            return "重置密码"
        case .bindEmail:
            return "绑定邮箱"
        }
    }
}

class EmailCodeViewModel: ObservableObject {

    /// 重新发送验证码的等待时间(秒)
    private static let RESEND_SECONDS = 60

    let type: EmailCodeType

    /// 服务器地址,从登录页面传过来,绑定邮箱时不需要
    let domain: String

    @Published var email = ""

    @Published var code = ""

    @Published var pwd = ""

    @Published var repwd = ""

    /// 距离可以重新发送验证码的秒数,0表示可以发送
    @Published var countdown = 0

    private var timer: Timer?

    init(_ type: EmailCodeType, domain: String) {
        self.type = type
        self.domain = domain
    }

    /// 发送验证码点击事件
    func onSendCodeClick(){
        let email = self.email.trim()
        if email.isEmpty{
            Toast.show("请输入邮箱")
            return
        }
        let onSent = {
            Toast.show("验证码已发送,请查收邮件")
            self.startCountdown()
        }
        if self.type == .bindEmail{
            CommonApi.sendEmailCode(email: email, type: self.type.rawValue).send(onSent)
            return
        }
        
        //注册和重置密码时还没有登录,请求登录页面选择的服务器
        let domain = self.domain
        SettingShared.checkServer(domain: domain){ config in
            if self.type == .register && !config.allowRegister{
                Toast.show("该服务器没有开放注册")
                return
            }
            CommonApi.sendEmailCode(email: email, type: self.type.rawValue).domain(domain).send(onSent)
        }
    }
    
    /// 开始倒计时
    private func startCountdown(){
        self.countdown = EmailCodeViewModel.RESEND_SECONDS
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true){ [weak self] timer in
            guard let self else{
                timer.invalidate()
                return
            }
            self.countdown -= 1
            if self.countdown <= 0{
                timer.invalidate()
            }
        }
    }

    /// 提交按钮点击事件
    func onSubmitClick(){
        let email = self.email.trim()
        if email.isEmpty{
            Toast.show("请输入邮箱")
            return
        }
        if self.code.trim().isEmpty{
            Toast.show("请输入验证码")
            return
        }
        if self.pwd.count < 6 || self.pwd.count > 32{
            Toast.show("密码长度为6~32位")
            return
        }
        if self.pwd != self.repwd{
            Toast.show("两次输入的密码不一致")
            return
        }
        let code = self.code.trim()
        let pwd = self.pwd
        switch self.type {
        case .register:
            SettingShared.login(domain: self.domain, request: {
                UserApi.register(email: email, pwd: pwd, code: code)
            }, success: {
                Toast.show("注册成功")
                DiscoverPage().relaunch()
            })
        case .resetPwd:
            let domain = self.domain
            UserApi.resetPwd(email: email, code: code, pwd: pwd).domain(domain).send{
                Toast.show("密码已重置,请重新登录")
                LoginPage(LoginViewModel(domain: domain, email: email)).relaunch()
            }
        case .bindEmail:
            UserApi.bindEmail(email: email, code: code, pwd: pwd).send{ _ in
                Toast.show("绑定成功")
                SettingShared.loadUserInBackground()
                MinePage().relaunch()
            }
        }
    }

    deinit {
        self.timer?.invalidate()
    }
}
