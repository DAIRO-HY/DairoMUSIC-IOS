//
//  DairoMUSICUITests.swift
//  DairoMUSIC-IOSUITests
//
//  Created by zhoulq on 2026/11/07.
//

import XCTest

/// 不需要歌曲的功能:免注册登录、歌单增删改、个人资料、检查更新、意见反馈、缓存管理、账号列表、退出登录
/// 运行前需要卸载App,保证从登录页开始;服务器地址通过环境变量TEST_RUNNER_SERVER传入
final class DairoMUSICUITests: DairoUITestCase {

    override var shotPrefix: String {
        return "N"
    }

    @MainActor
    func testWithoutMusic() throws {
        //登录页,免注册使用
        XCTAssertTrue(self.app.textFields["例 192.168.1.100:8020"].waitForExistence(timeout: 10))
        self.shot("服务器页")

        //登录页:注册在最左边,忘记密码在最右边
        self.toLoginPage()
        let register = self.app.buttons["注册"]
        let forget = self.app.buttons["忘记密码"]
        XCTAssertTrue(register.waitForExistence(timeout: 5))
        let window = self.app.windows.firstMatch.frame
        XCTAssertLessThan(register.frame.minX - window.minX, 40, "注册应该在最左边")
        XCTAssertLessThan(window.maxX - forget.frame.maxX, 40, "忘记密码应该在最右边")
        self.shot("登录页")
        self.app.buttons["免注册使用"].tap()
        XCTAssertTrue(self.app.buttons["搜索歌曲、歌手"].waitForExistence(timeout: 10))

        //首页
        XCTAssertTrue(self.app.buttons["搜索歌曲、歌手"].waitForExistence(timeout: 10))
        self.shot("首页")

        //音乐页,新建两个歌单
        self.app.buttons["音乐"].tap()
        XCTAssertTrue(self.app.staticTexts["我喜欢的音乐"].waitForExistence(timeout: 10))
        self.createFavorite("测试歌单A")
        self.createFavorite("测试歌单B")
        self.shot("新建歌单之后")

        //修改歌单名
        self.app.staticTexts["测试歌单A"].tap()
        XCTAssertTrue(self.app.staticTexts["没有歌曲"].waitForExistence(timeout: 10))
        self.shot("空歌单")
        self.app.buttons["编辑歌单"].tap()
        let nameField = self.app.textFields["请输入歌单名"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.clearAndType("测试歌单A2")
        self.app.buttons["保存"].tap()
        XCTAssertTrue(self.app.staticTexts["保存成功"].waitForExistence(timeout: 10))
        self.shot("编辑歌单")
        self.app.navigationBars.buttons.element(boundBy: 0).tap()
        self.app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(self.app.staticTexts["测试歌单A2"].waitForExistence(timeout: 10))

        //左滑删除歌单
        self.app.staticTexts["测试歌单B"].swipeLeft()
        self.shot("左滑删除")
        self.app.buttons["删除"].firstMatch.tap()
        let deleteAlert = self.app.alerts.firstMatch
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 5))
        deleteAlert.buttons["删除"].tap()
        XCTAssertTrue(self.app.staticTexts["测试歌单B"].waitForNonExistence(timeout: 10))
        self.shot("删除歌单之后")

        //我的页面
        self.app.buttons["我的"].tap()
        XCTAssertTrue(self.app.staticTexts["临时会员"].waitForExistence(timeout: 10))
        self.shot("我的")

        //定时停止播放:选择15分钟之后显示停止时间和"播完整首歌再停止",再取消
        self.app.button(startsWith: "定时停止播放").tap()
        XCTAssertTrue(self.app.buttons["15分钟"].waitForExistence(timeout: 5))
        self.app.buttons["15分钟"].tap()
        if !self.app.button(startsWith: "定时停止播放").waitForExistence(timeout: 3){
            self.back()
        }
        let endText = self.app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "将在")).firstMatch
        XCTAssertTrue(endText.waitForExistence(timeout: 5))
        XCTAssertTrue(self.app.switches["播完整首歌再停止"].exists)
        self.shot("定时停止播放")
        self.app.button(startsWith: "定时停止播放").tap()
        XCTAssertTrue(self.app.buttons["不开启"].waitForExistence(timeout: 5))
        self.app.buttons["不开启"].tap()
        if !self.app.button(startsWith: "定时停止播放").waitForExistence(timeout: 3){
            self.back()
        }
        XCTAssertFalse(endText.waitForExistence(timeout: 2))
        XCTAssertFalse(self.app.switches["播完整首歌再停止"].exists)

        //自定义停止时间:取消时不开启,确定之后显示停止时间
        self.app.button(startsWith: "定时停止播放").tap()
        XCTAssertTrue(self.app.buttons["自定义"].waitForExistence(timeout: 5))
        self.app.buttons["自定义"].tap()
        XCTAssertTrue(self.app.navigationBars["自定义停止时间"].waitForExistence(timeout: 5))
        self.app.buttons["取消"].tap()
        XCTAssertFalse(endText.waitForExistence(timeout: 2), "取消自定义时不开启定时")
        self.app.button(startsWith: "定时停止播放").tap()
        XCTAssertTrue(self.app.buttons["自定义"].waitForExistence(timeout: 5))
        self.app.buttons["自定义"].tap()
        XCTAssertTrue(self.app.navigationBars["自定义停止时间"].waitForExistence(timeout: 5))
        self.shot("自定义停止时间")
        self.app.buttons["确定"].tap()
        XCTAssertTrue(endText.waitForExistence(timeout: 5))
        XCTAssertTrue(self.app.button(startsWith: "定时停止播放, 自定义").exists || self.app.staticTexts["自定义"].exists)
        self.shot("自定义定时")

        //取消定时
        self.app.button(startsWith: "定时停止播放").tap()
        XCTAssertTrue(self.app.buttons["不开启"].waitForExistence(timeout: 5))
        self.app.buttons["不开启"].tap()
        XCTAssertFalse(endText.waitForExistence(timeout: 2))

        //修改昵称,临时会员可以在个人资料里绑定邮箱
        self.app.button(startsWith: "个人资料").tap()
        let nickField = self.app.textFields["请输入昵称"]
        XCTAssertTrue(nickField.waitForExistence(timeout: 5))
        XCTAssertTrue(self.app.button(startsWith: "绑定邮箱").exists)
        nickField.tap()
        nickField.clearAndType("测试昵称")
        self.app.buttons["保存昵称"].tap()
        XCTAssertTrue(self.app.staticTexts["保存成功"].waitForExistence(timeout: 10))
        self.shot("个人资料")
        self.app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(self.app.staticTexts["测试昵称"].waitForExistence(timeout: 10))

        //缓存管理
        self.app.button(startsWith: "缓存管理").tap()
        XCTAssertTrue(self.app.buttons["清理全部缓存"].waitForExistence(timeout: 5))

        //音乐默认边播边缓存,视频默认在线播放
        XCTAssertEqual(self.app.switches["音乐边播边缓存"].value as? String, "1")
        XCTAssertEqual(self.app.switches["视频边播边缓存"].value as? String, "0")
        self.shot("缓存管理")
        self.app.navigationBars.buttons.element(boundBy: 0).tap()

        //意见反馈
        self.app.buttons["意见反馈"].tap()
        let editor = self.app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("UI自动测试的反馈")
        self.shot("意见反馈")
        self.app.buttons["提交"].tap()
        XCTAssertTrue(self.app.buttons["关于"].waitForExistence(timeout: 10))

        //关于,检查更新
        self.app.buttons["关于"].tap()
        self.app.buttons["检查更新"].tap()
        XCTAssertTrue(self.app.staticTexts["已经是最新版本"].waitForExistence(timeout: 10))
        self.shot("关于")
        self.app.navigationBars.buttons.element(boundBy: 0).tap()

        //账号列表
        self.app.staticTexts["测试昵称"].tap()
        XCTAssertTrue(self.app.staticTexts["选择账号"].waitForExistence(timeout: 5))
        self.shot("账号列表")
        self.app.navigationBars.buttons.element(boundBy: 0).tap()

        //退出登录
        self.app.swipeUp()
        self.app.buttons["退出登录"].tap()
        let logoutAlert = self.app.alerts.firstMatch
        XCTAssertTrue(logoutAlert.waitForExistence(timeout: 5))
        logoutAlert.buttons["退出"].tap()
        XCTAssertTrue(self.app.textFields["例 192.168.1.100:8020"].waitForExistence(timeout: 10))
        self.shot("退出登录之后")
    }

    /// 新建歌单
    private func createFavorite(_ name: String) {
        self.app.buttons["新建歌单"].tap()
        let alert = self.app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.textFields.firstMatch.typeText(name)
        alert.buttons["创建"].tap()
        XCTAssertTrue(self.app.staticTexts[name].waitForExistence(timeout: 10))
    }
}
