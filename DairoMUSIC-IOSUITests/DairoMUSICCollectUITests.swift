//
//  DairoMUSICCollectUITests.swift
//  DairoMUSIC-IOSUITests
//
//  Created by zhoulq on 2026/11/08.
//

import XCTest

/// 采集平台的歌曲:搜索、没有入库时直接播放、收藏时先加入曲库、从歌单播放
/// 需要DairoMUSIC服务端接上采集服务,并且测试歌曲已经采集好
/// 搜索结果是实时从采集平台获取的,排名会变,按标题匹配
final class DairoMUSICCollectUITests: DairoUITestCase {

    /// 搜索关键词
    private let key = "外国人翻唱 生日礼物"

    /// 已经采集好的测试歌曲标题开头
    private let titlePrefix = "外国人翻唱【生日礼物】"

    override var shotPrefix: String {
        return "C"
    }

    @MainActor
    func testCollect() throws {
        self.loginTemp()

        //搜索采集平台
        self.app.buttons["搜索歌曲、歌手"].tap()
        let searchField = self.app.textFields["搜索歌曲、歌手"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.typeText(self.key + "\n")
        //之前测试过时曲库里也会有这首歌,只找带采集平台标签(YT)的那一行
        let row = self.app.cells.containing(NSPredicate(format: "label BEGINSWITH %@", self.titlePrefix)).containing(.staticText, identifier: "YT").firstMatch
        let title = row.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", self.titlePrefix)).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 60))
        self.shot("采集平台搜索结果")

        //没有入库时直接播放采集平台的地址
        title.tap()
        XCTAssertTrue(self.hittableButton("暂停").waitForExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 5)
        self.shot("播放采集平台的歌曲")

        //打开播放页确认进度在走
        self.app.buttons["播放列表"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: -4, dy: 0.5)).tap()
        XCTAssertTrue(self.app.buttons["下一曲"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 2)
        self.shot("采集平台歌曲播放页")
        self.app.buttons["关闭"].tap()

        //收藏到"我喜欢的音乐",会先加入曲库
        row.buttons["更多操作"].tap()
        XCTAssertTrue(self.app.buttons["收藏到歌单"].waitForExistence(timeout: 5))
        XCTAssertFalse(self.app.button(startsWith: "纠错").exists, "没有入库的歌曲不能纠错")
        self.shot("采集平台歌曲详情")
        self.app.buttons["收藏到歌单"].tap()
        let like = self.app.buttons["我喜欢的音乐"]
        XCTAssertTrue(like.waitForExistence(timeout: 5))
        like.tap()
        self.waitToast("已收藏到「我喜欢的音乐」")

        //加入曲库之后可以纠错
        XCTAssertTrue(self.app.button(startsWith: "纠错").waitForExistence(timeout: 10))
        self.shot("加入曲库之后")
        self.dismissSheet()

        //从"我喜欢的音乐"播放
        self.back()
        self.app.buttons["音乐"].tap()
        self.app.staticTexts["我喜欢的音乐"].tap()
        //迷你播放条上也有同样的歌名,只在列表里找
        let likeTitle = self.app.cells.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", self.titlePrefix)).firstMatch
        XCTAssertTrue(likeTitle.waitForExistence(timeout: 10))
        likeTitle.tap()
        XCTAssertTrue(self.hittableButton("暂停").waitForExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 3)
        self.shot("从歌单播放")
        self.back()

        //退出登录
        self.app.buttons["我的"].tap()
        self.logout()
    }

    /// 采集新歌:随机挑一首采集平台的歌曲播放,没有采集过时会先显示采集进度,采集完成之后自动播放
    /// 采集服务会缓存采集过的歌曲,随机挑选尽量避开采集过的
    @MainActor
    func testCollectNewSong() throws {
        self.loginTemp()
        self.app.buttons["搜索歌曲、歌手"].tap()
        let searchField = self.app.textFields["搜索歌曲、歌手"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.typeText("生日礼物 吉他弹唱\n")

        //采集平台的结果都带YT标签
        let rows = self.app.cells.containing(.staticText, identifier: "YT")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 60))
        //只在屏幕上能点到的结果里挑,第一条通常是热门的,可能已经采集过
        let bottom = self.app.windows.firstMatch.frame.maxY - 150
        let visibleRows = rows.allElementsBoundByIndex.filter{ $0.isHittable && $0.frame.maxY < bottom }
        XCTAssertFalse(visibleRows.isEmpty)
        let row = visibleRows[Int.random(in: min(1, visibleRows.count - 1) ..< visibleRows.count)]
        row.tap()

        //采集进度显示在迷你播放条上
        Thread.sleep(forTimeInterval: 3)
        self.shot("采集进度")

        //采集完成之后开始播放,最多等3分钟
        XCTAssertTrue(self.hittableButton("暂停").waitForExistence(timeout: 180))
        Thread.sleep(forTimeInterval: 5)
        self.shot("采集完成开始播放")
        self.app.buttons["播放列表"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: -4, dy: 0.5)).tap()
        XCTAssertTrue(self.app.buttons["下一曲"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 2)
        self.shot("新歌播放页")
        self.app.buttons["关闭"].tap()
        self.back()
        self.app.buttons["我的"].tap()
        self.logout()
    }

    /// 在歌曲信息页"喜欢"还没有入库的采集平台歌曲,加入曲库之后按钮变成"取消喜欢",再点可以取消
    @MainActor
    func testLikeCollectSong() throws {
        self.loginTemp()
        self.app.buttons["搜索歌曲、歌手"].tap()
        let searchField = self.app.textFields["搜索歌曲、歌手"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.typeText("周杰伦 晴天\n")
        let row = self.app.cells.containing(.staticText, identifier: "YT").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 60))
        row.buttons["更多操作"].tap()
        XCTAssertTrue(self.app.buttons["喜欢"].waitForExistence(timeout: 5))
        self.app.buttons["喜欢"].tap()
        XCTAssertTrue(self.app.buttons["取消喜欢"].waitForExistence(timeout: 30), "喜欢之后应该显示取消喜欢")
        self.shot("喜欢采集平台的歌曲")
        self.app.buttons["取消喜欢"].tap()
        XCTAssertTrue(self.app.buttons["喜欢"].waitForExistence(timeout: 10), "取消喜欢之后应该显示喜欢")
        self.dismissSheet()
        self.back()
        self.app.buttons["我的"].tap()
        self.logout()
    }
}
