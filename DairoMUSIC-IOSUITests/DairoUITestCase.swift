//
//  DairoUITestCase.swift
//  DairoMUSIC-IOSUITests
//
//  Created by zhoulq on 2026/11/08.
//

import XCTest

/// UI测试的公共方法
/// 环境变量(xcodebuild运行时加TEST_RUNNER_前缀传入):
/// SERVER:服务器地址,默认127.0.0.1:8020
/// SHOT_DIR:截图保存目录,为空时不保存
class DairoUITestCase: XCTestCase {

    var app: XCUIApplication!

    /// 服务器地址
    let server = ProcessInfo.processInfo.environment["SERVER"] ?? "127.0.0.1:8020"

    /// 截图保存目录
    private let shotDir = ProcessInfo.processInfo.environment["SHOT_DIR"]

    /// 截图文件名前缀,区分不同的测试
    var shotPrefix: String {
        return ""
    }

    /// 截图序号
    private var shotIndex = 0

    override func setUpWithError() throws {
        continueAfterFailure = false
        self.app = XCUIApplication()

        //播放页的引导只在第一次进入时显示,会挡住其他测试,通过启动参数跳过,引导单独测试
        //视频控制按钮默认3秒自动隐藏,测试时找按钮比较慢,加长到10秒
        self.app.launchArguments = ["-PLAYING_GUIDE_SHOWN", "YES", "-VIDEO_CONTROLS_HIDE_SECONDS", "10"]
        self.app.launch()
    }

    /// 截图保存到指定目录
    func shot(_ name: String) {
        guard let shotDir = self.shotDir else{
            return
        }

        //等动画和Toast显示出来
        Thread.sleep(forTimeInterval: 0.8)
        self.shotIndex += 1
        let path = shotDir + "/" + self.shotPrefix + String(format: "%02d-", self.shotIndex) + name + ".png"
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: path))
    }

    /// 同名的按钮有多个时,获取能点击的那个
    func hittableButton(_ label: String) -> XCUIElement {
        return self.app.buttons.matching(identifier: label).allElementsBoundByIndex.first{ $0.isHittable } ?? self.app.buttons[label].firstMatch
    }

    /// 同样提示文字的输入框有多个时(比如下面还有登录页),获取能点击的那个
    func hittableTextField(_ placeholder: String) -> XCUIElement {
        return self.app.textFields.matching(identifier: placeholder).allElementsBoundByIndex.last{ $0.isHittable } ?? self.app.textFields[placeholder].firstMatch
    }

    /// 返回上一页
    func back() {
        self.app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    /// 等待进入首页,失败时截图
    /// 用密码登录、注册成功之后系统会弹出"保存密码?",这里点"以后"关掉
    func waitHome(file: StaticString = #filePath, line: UInt = #line) {
        if !self.app.buttons["搜索歌曲、歌手"].waitForExistence(timeout: 10){
            self.shot("没有进入首页")
            XCTFail("没有进入首页", file: file, line: line)
            return
        }
        self.dismissSavePassword()

        //等对话框消失的动画结束,否则接下来的点击会被吃掉
        Thread.sleep(forTimeInterval: 1)
    }

    /// 关闭系统的"保存密码?"对话框,对话框不属于App,先在系统进程里找按钮,找不到时按坐标点击
    func dismissSavePassword() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let later = springboard.buttons["以后"]
        if later.waitForExistence(timeout: 3){
            later.tap()
            return
        }
        if self.app.buttons["以后"].exists{
            self.app.buttons["以后"].tap()
            return
        }

        //对话框挡住了App时,App的元素点不到
        if !self.app.buttons["我的"].isHittable{
            self.app.coordinate(withNormalizedOffset: CGVector(dx: 0.315, dy: 0.615)).tap()
        }
    }

    /// 点系统"保存密码?"对话框的"以后",iPad上对话框在App里,iPhone上在系统进程里,都找不到按钮时按坐标点击
    func tapSavePasswordLater() {
        let later = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["以后"]
        if self.app.buttons["以后"].waitForExistence(timeout: 2){
            self.app.buttons["以后"].tap()
        } else if later.exists{
            later.tap()
        } else {
            self.app.coordinate(withNormalizedOffset: CGVector(dx: 0.315, dy: 0.615)).tap()
        }
    }

    /// 关闭弹出的sheet页面,iPhone上向下滑动,iPad上sheet显示在屏幕中间,点sheet外面关闭
    func dismissSheet() {
        if UIDevice.current.userInterfaceIdiom == .pad{
            self.app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).tap()
        } else {
            self.app.swipeDown(velocity: .fast)
        }
    }

    /// 打开播放页面,从歌单、搜索结果点击歌曲之后已经自动打开时不处理,其他时候点击迷你播放条打开
    func openPlayingPage() {
        if self.app.buttons["关闭"].waitForExistence(timeout: 2){
            return
        }
        self.app.buttons["播放列表"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: -4, dy: 0.5)).tap()
        XCTAssertTrue(self.app.buttons["关闭"].waitForExistence(timeout: 5))
    }

    /// 关闭播放页面,点击歌曲之后自动打开了播放页面,回到列表继续操作
    func closePlayingPage() {
        let close = self.app.buttons["关闭"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertFalse(close.waitForExistence(timeout: 2))
    }

    /// 等待Toast提示
    func waitToast(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        if !self.app.staticTexts[text].waitForExistence(timeout: 10){
            self.shot("没有出现提示-" + text)
            XCTFail("没有出现提示:" + text, file: file, line: line)
        }
    }

    /// 在服务器页面填写服务器地址,进入登录页面
    func toLoginPage() {
        let serverField = self.app.textFields["例 192.168.1.100:8020"]
        XCTAssertTrue(serverField.waitForExistence(timeout: 10))
        serverField.clearAndType(self.server)

        //注册、登录之后离开有密码的页面时,系统会弹出"保存密码?"挡住页面
        if !self.app.buttons["下一步"].isHittable{
            self.tapSavePasswordLater()
            Thread.sleep(forTimeInterval: 1)
        }
        self.app.buttons["下一步"].tap()
        if !self.app.textFields["邮箱或用户名"].waitForExistence(timeout: 10){
            self.shot("没有进入登录页")
            XCTFail("没有进入登录页")
        }
    }

    /// 从服务器页面开始,免注册使用
    func loginTemp() {
        self.toLoginPage()
        self.app.buttons["免注册使用"].tap()
        XCTAssertTrue(self.app.buttons["搜索歌曲、歌手"].waitForExistence(timeout: 10))
    }

    /// 填写邮箱、密码之后点登录,在服务器页面时先填写服务器地址进入登录页面
    func fillLogin(email: String, pwd: String) {
        if self.app.textFields["例 192.168.1.100:8020"].waitForExistence(timeout: 3){
            self.toLoginPage()
        }
        self.app.textFields["邮箱或用户名"].clearAndType(email)
        self.typePassword(self.app.secureTextFields["请输入密码"], pwd)
        self.hittableButton("登录").tap()
    }

    /// 输入密码,新密码的输入框会弹出系统的"使用强密码?"面板,这时点面板右上角的关闭按钮
    /// iPhone上面板代替了键盘且不属于App,只能按坐标点击
    func typePassword(_ field: XCUIElement, _ text: String) {
        field.tap()

        //iPad上"使用强密码?"面板和键盘同时出现,直接点面板的关闭按钮
        let closeStrongPwd = self.app.buttons["xmark"]
        if closeStrongPwd.waitForExistence(timeout: 2){
            closeStrongPwd.tap()
            if !self.app.keyboards.firstMatch.waitForExistence(timeout: 2){
                field.tap()
            }
        }
        if !self.app.keyboards.firstMatch.waitForExistence(timeout: 2){
            self.app.coordinate(withNormalizedOffset: CGVector(dx: 0.909, dy: 0.58)).tap()
            if !self.app.keyboards.firstMatch.waitForExistence(timeout: 2){
                field.tap()
            }
        }
        field.typeText(text)
    }

    /// 从登录页打开注册、忘记密码页面
    /// 登录失败之后系统可能会弹出"保存密码?",第一次点击会被对话框挡住,这时点"以后"关掉对话框再点一次
    func openFromLogin(_ title: String) {
        self.app.buttons[title].tap()
        if self.app.textFields["请输入验证码"].waitForExistence(timeout: 3){
            return
        }
        if !self.app.buttons[title].isHittable{
            self.tapSavePasswordLater()
            Thread.sleep(forTimeInterval: 1)
        }
        self.app.buttons[title].tap()
        if !self.app.textFields["请输入验证码"].waitForExistence(timeout: 5){
            self.shot("没有打开" + title)
            XCTFail("没有打开" + title)
        }
        Thread.sleep(forTimeInterval: 1)
    }

    /// 在我的页面退出登录
    func logout() {
        if !self.app.buttons["退出登录"].isHittable{
            self.app.swipeUp()
        }
        self.app.buttons["退出登录"].tap()
        let alert = self.app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["退出"].tap()
        XCTAssertTrue(self.app.textFields["例 192.168.1.100:8020"].waitForExistence(timeout: 10))
    }

    /// 请求不需要登录的接口
    func getJson(_ path: String) -> [String: Any]? {
        let host = self.server.hasPrefix("http") ? self.server : "http://" + self.server
        let semaphore = DispatchSemaphore(value: 0)
        var result: [String: Any]?
        URLSession.shared.dataTask(with: URL(string: host + path)!){ data, _, _ in
            result = data.flatMap{ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return result
    }

    /// 从服务器的开发接口获取最近一次发送的邮箱验证码,只能从本机访问
    func emailCode(_ email: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        let host = self.server.hasPrefix("http") ? self.server : "http://" + self.server
        let url = URL(string: host + "/api/dev/email_code?email=" + email)!
        for _ in 0 ..< 10{
            let semaphore = DispatchSemaphore(value: 0)
            var code: String?
            URLSession.shared.dataTask(with: url){ data, _, _ in
                if let data, let json = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any]{
                    code = json["code"] as? String
                }
                semaphore.signal()
            }.resume()
            semaphore.wait()
            if let code{
                return code
            }
            Thread.sleep(forTimeInterval: 1)
        }
        XCTFail("没有获取到验证码:" + email, file: file, line: line)
        return ""
    }

    /// 填写邮箱验证码页面:发送验证码,获取验证码,填写密码之后提交
    /// - Parameter submit: 提交按钮的标题
    func fillEmailCode(email: String, pwd: String, submit: String) {
        //登录页的密码框有内容时离开登录页,系统会弹出"保存密码?"挡住新页面,点"以后"关掉
        var emailField = self.hittableTextField("请输入邮箱")
        if !emailField.isHittable{
            self.tapSavePasswordLater()
            Thread.sleep(forTimeInterval: 1)
            emailField = self.hittableTextField("请输入邮箱")
        }
        XCTAssertTrue(emailField.isHittable)
        self.shot(submit + "页面")
        emailField.clearAndType(email)
        self.app.buttons["发送验证码"].tap()
        self.waitToast("验证码已发送,请查收邮件")
        let code = self.emailCode(email)
        let codeField = self.app.textFields["请输入验证码"]
        codeField.tap()
        codeField.typeText(code)
        self.typePassword(self.app.secureTextFields["6~32位"], pwd)
        self.typePassword(self.app.secureTextFields["请再次输入密码"], pwd)
        self.shot("填写" + submit)
        self.hittableButton(submit).tap()
    }
}

extension XCUIApplication {

    /// 按标题开头查找按钮,带说明文字的设置项,按钮的标签是标题和说明连在一起的
    func button(startsWith title: String) -> XCUIElement {
        return self.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }
}

extension XCUIElement {

    /// 清空输入框之后再输入,有内容时再点最右边让光标移到末尾
    func clearAndType(_ text: String) {
        self.tap()
        if let value = self.value as? String, !value.isEmpty, value != self.placeholderValue{

            //文字右对齐,点输入框最右边2pt的位置把光标放到最后,iPad上输入框很宽,按比例点会点到最后一个字前面
            self.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -2, dy: 0)).tap()
            self.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        self.typeText(text)
    }
}
