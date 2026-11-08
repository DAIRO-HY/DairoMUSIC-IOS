//
//  DairoMUSICDownloadUITests.swift
//  DairoMUSIC-IOSUITests
//
//  Created by zhoulq on 2026/11/08.
//

import XCTest

/// 歌曲下载:歌曲信息页选择音质下载、歌单全部下载、已下载列表的进度和删除
/// 需要服务器允许下载歌曲(管理后台"允许下载歌曲"),"测试推荐·中文"歌单里有3首测试歌曲
final class DairoMUSICDownloadUITests: DairoUITestCase {

    override var shotPrefix: String {
        return "D"
    }

    @MainActor
    func testDownload() throws {
        let config = self.getJson("/api/common/config")
        try XCTSkipIf(config?["allowDownloadMusic"] as? Bool != true, "服务器不允许下载歌曲,跳过")
        self.loginTemp()

        //歌曲信息页下载,选择音质
        self.app.buttons["搜索歌曲、歌手"].tap()
        let searchField = self.app.textFields["搜索歌曲、歌手"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.typeText("测试歌手A\n")
        XCTAssertTrue(self.app.staticTexts["晴空之歌"].waitForExistence(timeout: 10))
        self.app.cells.containing(.staticText, identifier: "晴空之歌").firstMatch.buttons["更多操作"].tap()
        let download = self.app.button(startsWith: "下载")
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.tap()
        let quality = self.app.buttons["超高品质(320K)"]
        XCTAssertTrue(quality.waitForExistence(timeout: 5))
        self.shot("选择音质")
        quality.tap()
        self.waitToast("已加入下载列表")
        self.dismissSheet()
        self.back()

        //歌单全部下载
        let favorite = self.app.buttons["测试推荐·中文"].firstMatch
        XCTAssertTrue(favorite.waitForExistence(timeout: 10))
        favorite.tap()
        let downloadAll = self.app.buttons["全部下载"]
        XCTAssertTrue(downloadAll.waitForExistence(timeout: 10))
        self.shot("歌单")
        downloadAll.tap()
        let standard = self.app.buttons["标准(128K)"]
        XCTAssertTrue(standard.waitForExistence(timeout: 5))
        standard.tap()
        self.waitToast("已加入下载列表3首")
        self.back()

        //缓存管理里的已下载的歌曲:晴空之歌320K和歌单里的3首128K
        self.app.buttons["我的"].tap()
        self.app.button(startsWith: "缓存管理").tap()
        let musicDownloads = self.app.button(startsWith: "已下载的歌曲")
        XCTAssertTrue(musicDownloads.waitForExistence(timeout: 5))
        musicDownloads.tap()
        XCTAssertTrue(self.app.navigationBars["已下载的歌曲"].waitForExistence(timeout: 5))
        XCTAssertTrue(self.app.cells.element(boundBy: 3).waitForExistence(timeout: 10))
        XCTAssertEqual(self.app.cells.count, 4)
        self.shot("下载中")

        //等全部下载完成,下载完成之后不再显示进度条
        let progress = self.app.progressIndicators.firstMatch
        var finished = false
        for _ in 0 ..< 60{
            if !progress.exists{
                finished = true
                break
            }
            Thread.sleep(forTimeInterval: 1)
        }
        XCTAssertTrue(finished, "歌曲应该在60秒内下载完成")
        XCTAssertTrue(self.app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "超高品质(320K)")).firstMatch.exists)
        XCTAssertTrue(self.app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "标准(128K)")).firstMatch.exists)
        self.shot("下载完成")

        //左滑删除一个
        self.app.cells.firstMatch.swipeLeft()
        self.app.buttons["删除"].firstMatch.tap()
        XCTAssertTrue(self.waitCount(3))

        //多选删除两个
        self.app.buttons["选择"].tap()
        XCTAssertTrue(self.app.buttons["全选"].waitForExistence(timeout: 5))
        self.app.cells.element(boundBy: 0).tap()
        self.app.cells.element(boundBy: 1).tap()
        let deleteSelected = self.app.buttons["删除(2)"]
        XCTAssertTrue(deleteSelected.waitForExistence(timeout: 5))
        self.shot("多选")
        deleteSelected.tap()
        let selectedAlert = self.app.alerts.firstMatch
        XCTAssertTrue(selectedAlert.waitForExistence(timeout: 5))
        selectedAlert.buttons["删除"].tap()
        XCTAssertTrue(self.waitCount(1))
        XCTAssertTrue(self.app.buttons["选择"].waitForExistence(timeout: 5), "删除之后退出多选")

        //回到缓存管理,显示已下载的数量
        self.back()
        XCTAssertTrue(self.app.button(startsWith: "已下载的歌曲").waitForExistence(timeout: 5))
        XCTAssertTrue(self.app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "1首")).firstMatch.waitForExistence(timeout: 5))
        self.shot("缓存管理")

        //全部删除
        self.app.button(startsWith: "已下载的歌曲").tap()
        XCTAssertTrue(self.app.buttons["全部删除"].waitForExistence(timeout: 5))
        self.app.buttons["全部删除"].tap()
        let alert = self.app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["删除"].tap()
        XCTAssertTrue(self.app.staticTexts["没有下载的歌曲"].waitForExistence(timeout: 10))
        self.shot("全部删除之后")
        self.back()

        //已下载的视频页面
        self.app.button(startsWith: "已下载的视频").tap()
        XCTAssertTrue(self.app.navigationBars["已下载的视频"].waitForExistence(timeout: 5))
        self.back()
        self.back()
        self.logout()
    }

    /// 服务器不允许下载歌曲时不显示下载按钮,服务器允许下载时跳过
    @MainActor
    func testNoDownloadMusic() throws {
        let config = self.getJson("/api/common/config")
        try XCTSkipIf(config?["allowDownloadMusic"] as? Bool != false, "服务器允许下载歌曲,跳过")
        self.loginTemp()
        let favorite = self.app.buttons["测试推荐·中文"].firstMatch
        XCTAssertTrue(favorite.waitForExistence(timeout: 10))
        favorite.tap()
        XCTAssertTrue(self.app.staticTexts["3首"].waitForExistence(timeout: 10))
        XCTAssertFalse(self.app.buttons["全部下载"].exists, "不允许下载时不显示全部下载")
        self.app.cells.containing(.staticText, identifier: "海风").firstMatch.buttons["更多操作"].tap()
        XCTAssertTrue(self.app.buttons["分享"].waitForExistence(timeout: 5))
        XCTAssertFalse(self.app.button(startsWith: "下载").exists, "不允许下载时歌曲信息页不显示下载")
        self.shot("不允许下载")
        self.dismissSheet()
        self.back()
        self.app.buttons["我的"].tap()
        self.logout()
    }

    /// 等列表变成指定的行数
    private func waitCount(_ count: Int) -> Bool {
        for _ in 0 ..< 10{
            if self.app.cells.count == count{
                return true
            }
            Thread.sleep(forTimeInterval: 1)
        }
        return false
    }
}
