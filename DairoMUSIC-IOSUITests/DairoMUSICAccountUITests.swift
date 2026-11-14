//
//  DairoMUSICAccountUITests.swift
//  DairoMUSIC-IOSUITests
//
//  Created by zhoulq on 2026/11/08.
//

import XCTest

/// 账号相关:绑定邮箱、邮箱登录、错误密码、忘记密码、修改密码、注册、注销
/// 服务器需要用--mock-email启动,验证码通过开发接口获取
/// 测试结束时会注销用到的两个邮箱,可以重复运行
final class DairoMUSICAccountUITests: DairoUITestCase {

    /// 绑定邮箱用的测试邮箱
    private let email = "test@dairo.cn"

    /// 注册用的测试邮箱
    private let registerEmail = "test2@dairo.cn"

    /// 测试密码
    private let pwd = "123456"

    /// 重置之后的密码
    private let newPwd = "654321"

    override var shotPrefix: String {
        return "A"
    }

    override func setUpWithError() throws {

        //上次测试中途失败时测试邮箱可能还被占用,先注销掉
        for email in [self.email, self.registerEmail]{
            for pwd in [self.pwd, self.newPwd]{
                self.unregisterByApi(email: email, pwd: pwd)
            }
        }
        try super.setUpWithError()
    }

    @MainActor
    func testAccount() throws {

        //免注册使用之后在个人资料里绑定邮箱
        self.loginTemp()
        self.app.buttons["我的"].tap()
        XCTAssertFalse(self.app.button(startsWith: "绑定邮箱").exists, "我的页面不再显示绑定邮箱")
        self.app.button(startsWith: "个人资料").tap()
        XCTAssertTrue(self.app.button(startsWith: "绑定邮箱").waitForExistence(timeout: 5))
        self.app.button(startsWith: "绑定邮箱").tap()
        self.fillEmailCode(email: self.email, pwd: self.pwd, submit: "绑定邮箱")
        self.waitToast("绑定成功")
        XCTAssertTrue(self.app.staticTexts[self.email].waitForExistence(timeout: 10))
        XCTAssertTrue(self.app.buttons["修改密码"].exists)
        self.shot("绑定之后")

        //退出之后用邮箱登录
        self.logout()
        self.fillLogin(email: self.email, pwd: self.pwd)
        self.waitHome()
        self.app.buttons["我的"].tap()
        let found = self.app.staticTexts[self.email].waitForExistence(timeout: 10)
        self.shot("邮箱登录之后")
        XCTAssertTrue(found)
        self.logout()

        //密码错误
        self.fillLogin(email: self.email, pwd: "wrong-pwd")
        Thread.sleep(forTimeInterval: 1)
        self.shot("密码错误")
        XCTAssertTrue(self.app.buttons["免注册使用"].exists)

        //忘记密码,重置之后用新密码登录
        self.openFromLogin("忘记密码")
        self.fillEmailCode(email: self.email, pwd: self.newPwd, submit: "重置密码")
        self.waitToast("密码已重置,请重新登录")
        self.shot("重置密码之后")
        let pwdField = self.app.secureTextFields["请输入密码"]
        XCTAssertTrue(pwdField.waitForExistence(timeout: 5))
        self.typePassword(pwdField, self.newPwd)
        self.hittableButton("登录").tap()
        self.waitHome()

        //把密码改回来
        self.app.buttons["我的"].tap()
        self.app.buttons["修改密码"].tap()
        let oldField = self.app.secureTextFields["请输入当前密码"]
        XCTAssertTrue(oldField.waitForExistence(timeout: 5))
        self.typePassword(oldField, self.newPwd)
        self.typePassword(self.app.secureTextFields["6~32位"], self.pwd)
        self.typePassword(self.app.secureTextFields["请确认新密码"], self.pwd)
        self.app.buttons["修改"].tap()
        self.waitToast("修改成功")
        self.shot("修改密码")
        self.back()
        self.logout()
        self.fillLogin(email: self.email, pwd: self.pwd)
        self.waitHome()

        //账号列表里有这个账号,退出登录
        self.app.buttons["我的"].tap()
        self.app.staticTexts[self.email].tap()
        XCTAssertTrue(self.app.staticTexts["选择账号"].waitForExistence(timeout: 5))
        self.shot("账号列表")
        self.back()
        self.logout()

        //注册新账号
        self.toLoginPage()
        self.openFromLogin("注册")
        self.fillEmailCode(email: self.registerEmail, pwd: self.pwd, submit: "注册")
        self.waitToast("注册成功")
        self.waitHome()
        self.app.buttons["我的"].tap()
        XCTAssertTrue(self.app.staticTexts[self.registerEmail].waitForExistence(timeout: 10))
        self.shot("注册之后")

        //注销注册的账号,注销之后不能再登录
        self.unregister()
        self.fillLogin(email: self.registerEmail, pwd: self.pwd)
        Thread.sleep(forTimeInterval: 1)
        self.shot("注销之后登录")
        XCTAssertTrue(self.app.buttons["免注册使用"].exists)

        //注销绑定的账号,下次可以重新测试
        self.fillLogin(email: self.email, pwd: self.pwd)
        self.waitHome()
        self.app.buttons["我的"].tap()
        self.unregister()
    }

    /// 通过接口登录并注销账号,登录不上时什么也不做
    private func unregisterByApi(email: String, pwd: String) {
        let host = self.server.hasPrefix("http") ? self.server : "http://" + self.server
        let login = self.post(host + "/api/user/login", body: "account=\(email)&pwd=\(pwd)&deviceId=ui-test-clean&clientFlag=2&clientVersion=0", token: nil)
        guard let data = login, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let token = json["token"] as? String else{
            return
        }
        _ = self.post(host + "/api/user/unregister", body: "pwd=\(pwd)", token: token)
    }

    /// 同步发送POST请求,成功时返回响应内容
    private func post(_ url: String, body: String, token: String?) -> Data? {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let token{
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body.data(using: .utf8)
        let semaphore = DispatchSemaphore(value: 0)
        var result: Data?
        URLSession.shared.dataTask(with: request){ data, response, _ in
            if (response as? HTTPURLResponse)?.statusCode == 200{
                result = data
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return result
    }

    /// 在我的页面注销当前账号
    private func unregister() {
        self.app.button(startsWith: "个人资料").tap()
        let button = self.app.buttons["注销账号"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        let alert = self.app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.secureTextFields.firstMatch.typeText(self.pwd)
        alert.buttons["注销"].tap()
        self.waitToast("账号已注销")
        XCTAssertTrue(self.app.textFields["例 192.168.1.100:8020"].waitForExistence(timeout: 10))
    }
}
