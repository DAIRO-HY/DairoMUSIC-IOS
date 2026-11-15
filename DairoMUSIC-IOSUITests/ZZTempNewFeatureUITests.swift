import XCTest

//临时:发布前手动检查新功能用,测试完删除
//需要测试服务器上的tester01(只有用户名)和friend01(信任会员),密码都是123456
final class ZZTempNewFeatureUITests: DairoUITestCase {

    override var shotPrefix: String { "Z" }

    /// 用户名登录,个人资料显示用户名和绑定邮箱入口,绑定页面只填当前密码
    @MainActor
    func testUsernameLogin() throws {
        self.fillLogin(email: "TESTER01", pwd: "123456")
        self.waitHome()
        self.app.buttons["我的"].tap()
        XCTAssertTrue(self.app.staticTexts["tester01"].waitForExistence(timeout: 10))
        self.shot("用户名登录之后我的")
        self.app.button(startsWith: "个人资料").tap()
        XCTAssertTrue(self.app.staticTexts["用户名：tester01"].waitForExistence(timeout: 5))
        let bind = self.app.button(startsWith: "绑定邮箱")
        XCTAssertTrue(bind.exists)
        self.shot("只有用户名的个人资料")
        bind.tap()
        XCTAssertTrue(self.app.secureTextFields["请输入当前的登录密码"].waitForExistence(timeout: 5))
        XCTAssertFalse(self.app.secureTextFields["请再次输入密码"].exists, "确认身份时不需要确认密码")
        self.shot("只有用户名的绑定邮箱")
        self.back()
        self.back()
        self.app.buttons["我的"].tap()
        self.app.staticTexts["tester01"].tap()
        XCTAssertTrue(self.app.staticTexts["选择账号"].waitForExistence(timeout: 5))
        self.shot("账号列表显示用户名")
    }

    /// 只有用户名的会员绑定邮箱,用当前密码确认身份;会改变tester01,最后单独运行一次
    @MainActor
    func testUsernameBindEmail() throws {
        self.fillLogin(email: "tester01", pwd: "123456")
        self.waitHome()
        self.app.buttons["我的"].tap()
        self.app.button(startsWith: "个人资料").tap()
        self.app.button(startsWith: "绑定邮箱").tap()
        let email = "bindtest@dairo.cn"
        let emailField = self.hittableTextField("请输入邮箱")
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(email)
        self.app.buttons["发送验证码"].tap()
        self.waitToast("验证码已发送,请查收邮件")
        let code = self.emailCode(email)
        let codeField = self.app.textFields["请输入验证码"]
        codeField.tap()
        codeField.typeText(code)
        self.typePassword(self.app.secureTextFields["请输入当前的登录密码"], "123456")
        self.hittableButton("绑定邮箱").tap()
        self.waitToast("绑定成功")
        self.app.button(startsWith: "个人资料").tap()
        XCTAssertTrue(self.app.staticTexts["邮箱：" + email].waitForExistence(timeout: 10))
        XCTAssertTrue(self.app.staticTexts["用户名：tester01"].exists)
        self.shot("绑定邮箱之后")
    }

    /// 信任会员在歌曲信息页查看、修改审核状态
    @MainActor
    func testAudit() throws {
        self.fillLogin(email: "friend01", pwd: "123456")
        self.waitHome()
        self.search("测试歌手A")
        XCTAssertTrue(self.app.staticTexts["晴空之歌"].waitForExistence(timeout: 10))
        self.app.cells.containing(.staticText, identifier: "晴空之歌").firstMatch.buttons["更多操作"].tap()
        let audit = self.app.button(startsWith: "审核状态")
        XCTAssertTrue(audit.waitForExistence(timeout: 10))
        XCTAssertTrue(audit.label.contains("通过"), audit.label)
        self.shot("审核状态")
        audit.tap()
        XCTAssertTrue(self.app.buttons["拒绝"].waitForExistence(timeout: 5))
        XCTAssertTrue(self.app.buttons["待审核"].exists)
        self.shot("审核状态选择")
        self.app.buttons["通过"].firstMatch.tap()
        self.waitToast("审核状态已修改")
    }

    /// 下载之后发送歌曲文件:一种音质直接打开分享面板,多种音质先选择
    @MainActor
    func testSendFile() throws {
        self.loginTemp()
        self.search("测试歌手A")
        XCTAssertTrue(self.app.staticTexts["晴空之歌"].waitForExistence(timeout: 10))
        let more = self.app.cells.containing(.staticText, identifier: "晴空之歌").firstMatch.buttons["更多操作"]
        more.tap()
        XCTAssertFalse(self.app.button(startsWith: "发送歌曲文件").waitForExistence(timeout: 3), "没有下载时不显示")
        self.download("标准(128K)")

        //重新打开歌曲信息页,等下载完成
        more.tap()
        let send = self.app.button(startsWith: "发送歌曲文件")
        XCTAssertTrue(send.waitForExistence(timeout: 30))
        self.shot("发送歌曲文件")
        send.tap()
        Thread.sleep(forTimeInterval: 3)
        self.shot("分享面板")
        let file = self.app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "晴空之歌 - 测试歌手A")).firstMatch
        print("SHARE-FILE-NAME-FOUND=\(file.exists) \(file.exists ? file.label : "")")
        self.closeShareSheet()

        //再下载一种音质,发送时先选择
        self.download("超高品质(320K)")
        more.tap()
        XCTAssertTrue(send.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 10)
        self.dismissSheet()
        more.tap()
        XCTAssertTrue(send.waitForExistence(timeout: 10))
        send.tap()
        XCTAssertTrue(self.app.staticTexts["选择发送的音质"].waitForExistence(timeout: 5))
        self.shot("选择发送的音质")
    }

    /// 更换头像:从系统图片选择器选择一张图片上传
    @MainActor
    func testAvatar() throws {
        self.loginTemp()
        self.app.buttons["我的"].tap()
        self.app.button(startsWith: "个人资料").tap()
        let change = self.app.staticTexts["更换头像"]
        XCTAssertTrue(change.waitForExistence(timeout: 5))
        change.tap()
        Thread.sleep(forTimeInterval: 3)
        self.shot("图片选择器")
        let image = self.app.scrollViews.images.firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 10), "图片选择器里没有图片")
        image.tap()
        Thread.sleep(forTimeInterval: 8)
        self.shot("更换头像之后")
    }

    /// 从首页搜索
    private func search(_ key: String) {
        self.app.buttons["搜索歌曲、歌手"].tap()
        let searchField = self.app.textFields["搜索歌曲、歌手"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.typeText(key + "\n")
    }

    /// 在歌曲信息页下载指定音质,下载之后关闭歌曲信息页
    private func download(_ quality: String) {
        let download = self.app.button(startsWith: "下载")
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.tap()
        let option = self.app.button(startsWith: quality)
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        self.waitToast("已加入下载列表")
        self.dismissSheet()
    }

    /// 关闭系统分享面板
    private func closeShareSheet() {
        for label in ["关闭", "Close"]{
            let close = self.app.buttons[label].firstMatch
            if close.exists{
                close.tap()
                Thread.sleep(forTimeInterval: 1)
                return
            }
        }
        self.app.swipeDown()
        Thread.sleep(forTimeInterval: 1)
    }
}
