//
//  DairoMUSICMusicUITests.swift
//  DairoMUSIC-IOSUITests
//
//  Created by zhoulq on 2026/11/08.
//

import XCTest

/// 需要歌曲的功能:首页推荐、播放、播放页、搜索、喜欢、收藏到歌单、纠错、投诉、缓存
/// 服务器上需要有测试歌曲和推荐歌单,服务器地址通过环境变量TEST_RUNNER_SERVER传入
final class DairoMUSICMusicUITests: DairoUITestCase {

    override var shotPrefix: String {
        return "M"
    }

    @MainActor
    func testMusic() throws {
        self.loginTemp()

        //首页:轮播和推荐歌单
        XCTAssertTrue(self.app.buttons["测试推荐·中文"].firstMatch.waitForExistence(timeout: 10))
        self.shot("首页推荐")

        //推荐歌单,点第一首播放,播放列表是整个歌单
        self.app.buttons["测试推荐·中文"].firstMatch.tap()
        XCTAssertTrue(self.app.staticTexts["3首"].waitForExistence(timeout: 10))
        XCTAssertFalse(self.app.buttons["播放全部"].exists)
        self.shot("推荐歌单")
        self.app.staticTexts["海风"].tap()

        //迷你播放条出现,正在播放
        XCTAssertTrue(self.app.buttons["暂停"].waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 3)
        self.shot("播放中")

        //打开播放页
        self.app.buttons["播放列表"].coordinate(withNormalizedOffset: CGVector(dx: -4, dy: 0.5)).tap()
        XCTAssertTrue(self.app.buttons["下一曲"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 2)
        self.shot("播放页")

        //下一曲
        self.hittableButton("下一曲").tap()
        Thread.sleep(forTimeInterval: 3)
        XCTAssertTrue(self.app.buttons["暂停"].waitForExistence(timeout: 15))
        self.shot("下一曲")

        //左滑到歌词页
        self.app.swipeLeft()
        self.shot("歌词页")
        self.app.swipeRight()

        //播放列表,播放页下面还有迷你播放条的按钮,点能点到的那个
        self.hittableButton("播放列表").tap()
        XCTAssertTrue(self.app.navigationBars["播放列表(3)"].waitForExistence(timeout: 5))
        self.shot("播放列表")
        self.dismissSheet()
        self.app.buttons["关闭"].tap()

        //返回首页,搜索
        self.app.navigationBars.buttons.element(boundBy: 0).tap()
        self.app.buttons["搜索歌曲、歌手"].tap()
        let searchField = self.app.textFields["搜索歌曲、歌手"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.typeText("测试歌手A\n")
        XCTAssertTrue(self.app.staticTexts["晴空之歌"].waitForExistence(timeout: 10))
        self.shot("搜索结果")

        //歌曲详情,喜欢
        let row = self.app.cells.containing(.staticText, identifier: "晴空之歌").firstMatch
        row.buttons["更多操作"].tap()
        XCTAssertTrue(self.app.buttons["喜欢"].waitForExistence(timeout: 5))
        self.shot("歌曲详情")
        self.app.buttons["喜欢"].tap()
        XCTAssertTrue(self.app.buttons["取消喜欢"].waitForExistence(timeout: 10))

        //收藏到新建的歌单之前先投诉和纠错
        self.app.button(startsWith: "纠错").tap()
        let artistField = self.app.textFields["请输入歌手"]
        XCTAssertTrue(artistField.waitForExistence(timeout: 5))
        self.shot("纠错")
        self.app.buttons["提交"].tap()
        XCTAssertTrue(self.app.button(startsWith: "投诉").waitForExistence(timeout: 10))
        self.app.button(startsWith: "投诉").tap()
        XCTAssertTrue(self.app.buttons["音质不符"].waitForExistence(timeout: 10))
        self.app.buttons["音质不符"].tap()
        self.shot("投诉")
        self.app.buttons["提交"].tap()
        XCTAssertTrue(self.app.button(startsWith: "投诉").waitForExistence(timeout: 10))
        self.dismissSheet()

        //我喜欢的音乐里有这首歌
        self.app.navigationBars.buttons.element(boundBy: 0).tap()
        self.app.buttons["音乐"].tap()
        XCTAssertTrue(self.app.staticTexts["我喜欢的音乐"].waitForExistence(timeout: 10))
        XCTAssertTrue(self.app.staticTexts["最近播放"].exists)
        self.shot("我喜欢的音乐")
        self.app.staticTexts["我喜欢的音乐"].tap()
        XCTAssertTrue(self.app.staticTexts["晴空之歌"].waitForExistence(timeout: 10))
        self.shot("我喜欢的歌曲")
        self.app.navigationBars.buttons.element(boundBy: 0).tap()

        //最近播放
        self.app.staticTexts["最近播放"].tap()
        //播放过的歌曲都在里面,播放结束之后会自动播放下一首,所以不判断数量
        XCTAssertTrue(self.app.staticTexts["海风"].firstMatch.waitForExistence(timeout: 10))
        self.shot("最近播放")
        self.app.navigationBars.buttons.element(boundBy: 0).tap()

        //缓存管理里有歌曲缓存
        self.app.buttons["我的"].tap()
        self.app.button(startsWith: "缓存管理").tap()
        XCTAssertTrue(self.app.buttons["清理全部缓存"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        self.shot("缓存管理")
        self.app.navigationBars.buttons.element(boundBy: 0).tap()

        //退出登录
        self.app.swipeUp()
        self.app.buttons["退出登录"].tap()
        let logoutAlert = self.app.alerts.firstMatch
        XCTAssertTrue(logoutAlert.waitForExistence(timeout: 5))
        logoutAlert.buttons["退出"].tap()
        XCTAssertTrue(self.app.textFields["例 192.168.1.100:8020"].waitForExistence(timeout: 10))
    }

    /// 修改播放音质之后,下一首歌按新的音质播放,不用重新获取歌单
    @MainActor
    func testQualitySwitch() throws {
        self.loginTemp()

        //播放音质改成标准,播放歌单里的第一首
        self.setBitRate("标准(128K)")
        self.app.buttons["发现"].tap()
        let favorite = self.app.buttons["测试推荐·中文"].firstMatch
        XCTAssertTrue(favorite.waitForExistence(timeout: 10))
        favorite.tap()
        XCTAssertTrue(self.app.staticTexts["海风"].waitForExistence(timeout: 10))
        self.app.staticTexts["海风"].tap()
        XCTAssertTrue(self.hittableButton("暂停").waitForExistence(timeout: 15))
        self.app.cells.containing(.staticText, identifier: "海风").firstMatch.buttons["更多操作"].tap()
        XCTAssertEqual(self.currentQuality(), "当前音质：标准(128K)")
        self.shot("标准音质")
        self.dismissSheet()
        self.back()

        //改成超高品质,播放下一首,下一首按超高品质
        self.setBitRate("超高品质(320K)")
        self.app.buttons["播放列表"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: -4, dy: 0.5)).tap()
        XCTAssertTrue(self.app.buttons["下一曲"].waitForExistence(timeout: 5))
        self.hittableButton("下一曲").tap()
        XCTAssertTrue(self.hittableButton("暂停").waitForExistence(timeout: 15))
        self.hittableButton("更多操作").tap()
        XCTAssertEqual(self.currentQuality(), "当前音质：超高品质(320K)")
        self.shot("下一首超高品质")
        self.dismissSheet()
        self.hittableButton("暂停").tap()
        self.app.buttons["关闭"].tap()
        self.app.buttons["我的"].tap()
        self.logout()
    }

    /// 在我的页面修改播放音质
    private func setBitRate(_ label: String) {
        self.app.buttons["我的"].tap()
        let picker = self.app.button(startsWith: "播放音质")
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        XCTAssertTrue(self.app.buttons[label].waitForExistence(timeout: 5))
        self.app.buttons[label].tap()
        XCTAssertTrue(self.app.button(startsWith: "播放音质").waitForExistence(timeout: 5))
    }

    /// 歌曲信息页的当前音质
    private func currentQuality() -> String {
        let text = self.app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "当前音质：")).firstMatch
        return text.waitForExistence(timeout: 5) ? text.label : ""
    }

    /// 关闭"音乐边播边缓存"之后在线播放
    @MainActor
    func testMusicWithoutCache() throws {
        self.loginTemp()
        self.app.buttons["我的"].tap()
        self.app.button(startsWith: "缓存管理").tap()
        let musicCache = self.app.switches["音乐边播边缓存"]
        XCTAssertTrue(musicCache.waitForExistence(timeout: 5))
        musicCache.switches.firstMatch.tap()
        XCTAssertEqual(musicCache.value as? String, "0")
        self.shot("关闭音乐缓存")
        self.app.navigationBars.buttons.element(boundBy: 0).tap()

        //在线播放
        self.app.buttons["发现"].tap()
        self.app.buttons["搜索歌曲、歌手"].tap()
        let searchField = self.app.textFields["搜索歌曲、歌手"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.typeText("搁浅\n")
        let row = self.app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "搁浅")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(self.hittableButton("暂停").waitForExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 3)
        self.shot("在线播放")

        //恢复设置,退出登录
        self.hittableButton("暂停").tap()
        self.back()
        self.app.buttons["我的"].tap()
        self.app.button(startsWith: "缓存管理").tap()
        XCTAssertTrue(musicCache.waitForExistence(timeout: 5))
        musicCache.switches.firstMatch.tap()
        XCTAssertEqual(musicCache.value as? String, "1")
        self.app.navigationBars.buttons.element(boundBy: 0).tap()
        self.logout()
    }

    /// 第一次进入播放页时提示左边是视频、右边是歌词,第二次不再提示
    @MainActor
    func testPlayingGuide() throws {

        //启动参数设成没有显示过引导,App保存"已经显示"之后,不带参数重新启动时读取保存的值
        self.app.terminate()
        self.app.launchArguments = ["-PLAYING_GUIDE_SHOWN", "NO"]
        self.app.launch()
        self.loginTemp()
        let favorite = self.app.buttons["测试推荐·中文"].firstMatch
        XCTAssertTrue(favorite.waitForExistence(timeout: 10))
        favorite.tap()
        XCTAssertTrue(self.app.staticTexts["海风"].waitForExistence(timeout: 10))
        self.app.staticTexts["海风"].tap()
        XCTAssertTrue(self.app.buttons["暂停"].waitForExistence(timeout: 15))

        //第一次打开播放页显示引导
        self.app.buttons["播放列表"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: -4, dy: 0.5)).tap()
        let ok = self.app.buttons["知道了"]
        XCTAssertTrue(ok.waitForExistence(timeout: 5), "第一次进入播放页应该显示引导")
        XCTAssertTrue(self.app.staticTexts["视频"].exists && self.app.staticTexts["歌词"].exists)
        self.shot("播放页引导")
        ok.tap()
        XCTAssertFalse(ok.waitForExistence(timeout: 2))
        self.hittableButton("暂停").tap()
        self.app.buttons["关闭"].tap()

        //重新启动之后再进入播放页不再显示
        self.app.terminate()
        self.app.launchArguments = []
        self.app.launch()
        XCTAssertTrue(self.app.buttons["播放列表"].firstMatch.waitForExistence(timeout: 10))
        self.app.buttons["播放列表"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: -4, dy: 0.5)).tap()
        XCTAssertTrue(self.app.buttons["关闭"].waitForExistence(timeout: 5))
        XCTAssertFalse(self.app.buttons["知道了"].waitForExistence(timeout: 2), "第二次进入播放页不应该再显示引导")
        self.shot("第二次进入播放页")
        self.app.buttons["关闭"].tap()
        self.app.buttons["我的"].tap()
        self.logout()
    }
}
