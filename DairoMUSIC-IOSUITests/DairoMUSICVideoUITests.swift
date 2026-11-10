//
//  DairoMUSICVideoUITests.swift
//  DairoMUSIC-IOSUITests
//
//  Created by zhoulq on 2026/11/08.
//

import XCTest

/// 播放页的视频:切换到视频页面接管播放、切换清晰度、下载、下一个视频、没有视频的歌曲
/// 需要服务器上有采集好视频的测试歌曲:"稻香"两首有视频,"搁浅"原版没有视频、4K演唱会版有视频
final class DairoMUSICVideoUITests: DairoUITestCase {

    override var shotPrefix: String {
        return "V"
    }

    @MainActor
    func testVideo() throws {
        self.loginTemp()

        //播放"稻香 周杰伦 (歌词版)",播放列表是曲库的搜索结果
        self.search("稻香")
        self.libraryRow("稻香 周杰伦").tap()
        XCTAssertTrue(self.hittableButton("暂停").waitForExistence(timeout: 30))
        Thread.sleep(forTimeInterval: 5)
        self.openPlayingPage()

        //向右滑到视频页面,音乐暂停,视频开始播放
        self.app.swipeRight()
        self.waitVideo()
        Thread.sleep(forTimeInterval: 5)
        self.shot("视频播放中")

        //控制按钮显示时同时显示分辨率和帧率,例如:1080P 30FPS
        self.tapVideoControl(nil)
        let format = self.app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^(4K|2K|[0-9]+P)( [0-9]+FPS)?$")).firstMatch
        XCTAssertTrue(format.waitForExistence(timeout: 5), "应该显示分辨率和帧率")
        print("VIDEO-FORMAT=" + format.label)
        self.shot("分辨率和帧率")

        //切换到原画
        self.app.buttons["清晰度"].tap()
        self.app.buttons["原画"].tap()
        self.waitVideo()
        Thread.sleep(forTimeInterval: 3)
        self.shot("原画")

        //下载当前清晰度,服务器允许保存到相册时会先询问
        self.app.buttons["下载"].tap()
        let onlyDownload = self.app.buttons["只下载"]
        if onlyDownload.waitForExistence(timeout: 3){
            onlyDownload.tap()
        }
        XCTAssertTrue(self.app.buttons["已下载"].waitForExistence(timeout: 120))
        self.shot("下载完成")

        //下一个视频,播放列表里的另一首稻香
        self.app.buttons["下一个视频"].tap()
        self.waitVideo()
        XCTAssertTrue(self.app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Jay Chou")).firstMatch.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 3)
        self.shot("下一个视频")

        //拖到最后,播放结束之后自动播放下一个视频(播放列表里的另一首稻香)
        self.tapVideoControl(nil)
        self.app.sliders["视频进度"].adjust(toNormalizedSliderPosition: 0.995)
        let nextTitle = NSPredicate(format: "label BEGINSWITH %@", "稻香 周杰伦")
        var switched = false
        for _ in 0 ..< 30{
            let title = self.app.staticTexts.matching(nextTitle).firstMatch
            if title.exists && title.isHittable{
                switched = true
                break
            }
            Thread.sleep(forTimeInterval: 1)
        }
        XCTAssertTrue(switched, "视频播放结束之后应该自动播放下一个视频")
        self.waitVideo()
        self.shot("自动播放下一个视频")

        //回到封面页面,音乐跳到视频播放到的位置,保持暂停
        self.app.swipeLeft()
        XCTAssertTrue(self.hittableButton("播放").waitForExistence(timeout: 10), "离开视频页面之后音乐应该保持暂停")
        Thread.sleep(forTimeInterval: 2)
        self.shot("回到音乐")
        self.app.buttons["关闭"].tap()

        //没有视频的歌曲
        self.back()
        self.search("搁浅")
        self.libraryRow("搁浅").tap()
        XCTAssertTrue(self.hittableButton("暂停").waitForExistence(timeout: 30))
        self.openPlayingPage()
        self.app.swipeRight()
        XCTAssertTrue(self.app.staticTexts["该歌曲没有视频"].waitForExistence(timeout: 10))
        self.shot("没有视频")

        //下一个视频跳过没有视频的歌曲,播放4K演唱会版
        self.app.buttons["下一个视频"].tap()
        self.waitVideo()
        XCTAssertTrue(self.app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "4K修复")).firstMatch.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 5)
        self.shot("4K视频")
        self.app.swipeLeft()
        self.app.buttons["关闭"].tap()

        //退出登录
        self.back()
        self.app.buttons["我的"].tap()
        self.logout()
    }

    /// 下载并保存到相册,第一次保存时系统会询问添加照片的权限
    @MainActor
    func testSaveAlbum() throws {
        self.loginTemp()
        self.openVideo("稻香", "稻香 周杰伦")
        self.app.buttons["下载"].tap()
        let save = self.app.buttons["下载并保存到相册"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "服务器需要允许保存到相册")
        save.tap()

        //系统的相册权限询问框不属于App
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["允许"]
        if allow.waitForExistence(timeout: 60){
            self.shot("相册权限")
            allow.tap()
        }
        self.waitToast("已保存到相册")
        self.shot("已保存到相册")
        XCTAssertTrue(self.app.buttons["已下载"].exists)
        self.closeVideoAndLogout()
    }

    /// iPhone上全屏播放时可以横屏,其他页面只能竖屏;iPad上所有页面都可以横屏
    @MainActor
    func testFullScreen() throws {
        self.loginTemp()
        self.openVideo("稻香", "稻香 周杰伦")

        //iPhone上播放页不跟着旋转,iPad上播放页横屏显示左右布局
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 2)
        if UIDevice.current.userInterfaceIdiom == .pad{
            XCTAssertTrue(self.isLandscape, "iPad上播放页应该可以横屏")
            XCTAssertTrue(self.app.buttons["下一个视频"].isHittable)
            self.shot("iPad播放页横屏-视频")
            self.app.swipeLeft()
            XCTAssertTrue(self.app.buttons["播放"].waitForExistence(timeout: 5) || self.app.buttons["暂停"].exists)
            self.shot("iPad播放页横屏-封面")
            self.app.swipeRight()
        } else {
            XCTAssertFalse(self.isLandscape, "播放页不能横屏")
            self.shot("播放页横放手机")
        }
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1)

        //点全屏按钮,iPhone上自动切换到横屏
        self.tapVideoControl("全屏")
        if UIDevice.current.userInterfaceIdiom != .pad{
            XCTAssertTrue(self.waitLandscape(true), "全屏时应该是横屏")
        }
        self.tapVideoControl(nil)
        XCTAssertTrue(self.app.buttons["退出全屏"].exists)
        self.shot("全屏")

        //拖动进度条
        let slider = self.app.sliders["视频进度"]
        if !slider.isHittable{
            self.tapVideoControl(nil)
        }
        slider.adjust(toNormalizedSliderPosition: 0.5)
        Thread.sleep(forTimeInterval: 3)
        self.shot("全屏拖动进度")

        //全屏时播放结束,自动播放下一个视频(另一首稻香),依然全屏
        if !slider.isHittable{
            self.tapVideoControl(nil)
        }
        slider.adjust(toNormalizedSliderPosition: 0.995)
        let nextTitle = self.app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Jay Chou")).firstMatch
        XCTAssertTrue(nextTitle.waitForExistence(timeout: 30), "播放结束之后应该播放下一个视频")
        XCTAssertTrue(self.app.otherElements["视频"].waitForExistence(timeout: 30))
        if UIDevice.current.userInterfaceIdiom != .pad{
            XCTAssertTrue(self.waitLandscape(true), "播放下一个视频时应该依然全屏横屏")
        }
        self.tapVideoControl(nil)
        XCTAssertTrue(self.app.buttons["退出全屏"].exists, "播放下一个视频时应该依然全屏")
        self.shot("全屏播放下一个视频")

        //退出全屏,iPhone上回到竖屏,视频继续播放
        self.tapVideoControl("退出全屏")
        if UIDevice.current.userInterfaceIdiom != .pad{
            XCTAssertTrue(self.waitLandscape(false), "退出全屏之后应该回到竖屏")
        }
        XCTAssertTrue(self.app.buttons["下一个视频"].waitForExistence(timeout: 5))
        XCTAssertTrue(self.app.otherElements["视频"].exists, "退出全屏之后视频不能是黑屏")
        self.tapVideoControl(nil)
        XCTAssertTrue(self.app.buttons["暂停视频"].waitForExistence(timeout: 2) || self.app.activityIndicators.firstMatch.exists, "退出全屏之后视频应该继续播放")
        self.shot("退出全屏")
        self.closeVideoAndLogout()
    }

    /// 单曲循环时视频播放结束之后重新播放当前视频,不切换到下一个
    @MainActor
    func testVideoOneLoop() throws {
        self.loginTemp()
        self.openVideo("稻香", "稻香 周杰伦")

        //回到封面页面把播放顺序切换到单曲循环:列表循环 -> 随机播放 -> 单曲循环
        self.app.swipeLeft()
        XCTAssertTrue(self.hittableButton("列表循环").waitForExistence(timeout: 5))
        self.hittableButton("列表循环").tap()
        self.hittableButton("随机播放").tap()
        XCTAssertTrue(self.hittableButton("单曲循环").waitForExistence(timeout: 5))
        self.app.swipeRight()
        self.waitVideo()
        Thread.sleep(forTimeInterval: 3)

        //拖到最后,播放结束之后重新播放同一个视频
        self.tapVideoControl(nil)
        self.app.sliders["视频进度"].adjust(toNormalizedSliderPosition: 0.995)
        Thread.sleep(forTimeInterval: 8)
        let title = self.app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "稻香 周杰伦")).firstMatch
        XCTAssertTrue(title.exists && title.isHittable, "单曲循环时不应该切换到下一个视频")
        self.tapVideoControl(nil)
        let progress = Double((self.app.sliders["视频进度"].value as? String ?? "").replacingOccurrences(of: "%", with: "")) ?? 100
        XCTAssertLessThan(progress, 50, "单曲循环时应该从头重新播放")
        XCTAssertTrue(self.app.buttons["暂停视频"].exists, "重新播放之后应该是播放状态")
        self.shot("单曲循环重新播放")

        //恢复列表循环
        self.app.swipeLeft()
        self.hittableButton("单曲循环").tap()
        XCTAssertTrue(self.hittableButton("列表循环").waitForExistence(timeout: 5))
        self.app.buttons["关闭"].tap()
        self.back()
        self.app.buttons["我的"].tap()
        self.logout()
    }

    /// 老歌第一次打开视频页面时服务器开始采集,页面显示采集、转码的提示,完成之后自动播放
    /// 需要一首视频还没有采集的歌曲(videoState=0),这里用歌曲10"外国人翻唱",服务器单线程处理,1080p大约1~2分钟
    @MainActor
    func testOldSongCollect() throws {
        let music = self.getJson("/api/public/music?id=10")
        try XCTSkipIf(music?["videoState"] as? Int != 0, "测试歌曲的视频已经采集过,跳过")
        self.loginTemp()
        self.search("外国人翻唱")
        self.libraryRow("外国人翻唱").tap()
        XCTAssertTrue(self.hittableButton("暂停").waitForExistence(timeout: 30))
        self.openPlayingPage()
        self.app.swipeRight()
        let tip = self.app.staticTexts.matching(NSPredicate(format: "label == '服务器正在采集视频' OR label == '服务器正在转码中'")).firstMatch
        XCTAssertTrue(tip.waitForExistence(timeout: 15), "第一次打开视频页面时应该显示采集或转码的提示")
        self.shot("服务器正在采集")
        self.waitVideo(timeout: 420)
        Thread.sleep(forTimeInterval: 5)
        self.shot("采集完成开始播放")
        self.closeVideoAndLogout()
    }

    /// 还没有收藏的歌曲只能播放原画预览,播放之前确认流量
    @MainActor
    func testPreview() throws {
        self.loginTemp()
        self.search("周杰伦 搁浅")

        //采集平台的结果带YT标签
        let title = NSPredicate(format: "label BEGINSWITH %@", "周杰伦 Jay Chou【搁浅")
        let row = self.app.cells.containing(title).containing(.staticText, identifier: "YT").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 60))
        row.staticTexts.matching(title).firstMatch.tap()
        XCTAssertTrue(self.hittableButton("暂停").waitForExistence(timeout: 180))
        self.openPlayingPage()
        self.app.swipeRight()

        //当前清晰度是流畅时确认原画流量,已经选择原画时直接播放
        let alert = self.app.alerts.firstMatch
        if alert.waitForExistence(timeout: 10){
            self.shot("原画流量提示")
            alert.buttons["继续播放"].tap()
        }
        Thread.sleep(forTimeInterval: 2)
        self.shot("准备原画预览")
        self.waitVideo(timeout: 180)
        Thread.sleep(forTimeInterval: 5)
        self.shot("播放原画预览")

        //只能播放原画,不能切换清晰度
        let quality = self.app.buttons["清晰度"]
        XCTAssertFalse(quality.isEnabled)
        XCTAssertTrue(self.app.staticTexts["原画"].exists || quality.label.contains("原画") || self.app.buttons["原画"].exists)
        self.closeVideoAndLogout()
    }

    /// 服务器不允许保存到相册时,下载不询问,下载完成之后不能再点下载
    /// 服务器允许保存到相册时跳过
    @MainActor
    func testNoSaveAlbum() throws {
        let config = self.getJson("/api/common/config")
        try XCTSkipIf(config?["allowSaveAlbum"] as? Bool != false, "服务器允许保存到相册,跳过")
        self.loginTemp()
        self.openVideo("稻香", "稻香 周杰伦")
        self.app.buttons["下载"].tap()
        XCTAssertFalse(self.app.buttons["下载并保存到相册"].waitForExistence(timeout: 3), "不允许保存到相册时不应该询问")
        let downloaded = self.app.buttons["已下载"]
        XCTAssertTrue(downloaded.waitForExistence(timeout: 120))
        XCTAssertFalse(downloaded.isEnabled, "已经下载并且不允许保存到相册时不能再点")
        self.shot("不允许保存到相册")
        self.closeVideoAndLogout()
    }

    /// 服务器不允许下载视频时不显示下载按钮,服务器允许下载视频时跳过
    @MainActor
    func testNoDownloadVideo() throws {
        let config = self.getJson("/api/common/config")
        try XCTSkipIf(config?["allowDownloadVideo"] as? Bool != false, "服务器允许下载视频,跳过")
        self.loginTemp()
        self.openVideo("稻香", "稻香 周杰伦")
        XCTAssertTrue(self.app.buttons["下一个视频"].exists)
        XCTAssertFalse(self.app.buttons.matching(NSPredicate(format: "label IN %@", ["下载", "已下载"])).firstMatch.exists, "不允许下载视频时不显示下载按钮")
        self.shot("不允许下载视频")
        self.closeVideoAndLogout()
    }

    /// 后台删除了视频的歌曲(videoState=4)提示没有视频
    /// 测试歌曲"外国人翻唱"的视频没有被删除时跳过
    @MainActor
    func testDeletedVideo() throws {
        let music = self.getJson("/api/public/music?id=10")
        try XCTSkipIf(music?["videoState"] as? Int != 4, "测试歌曲的视频没有被删除,跳过")
        self.loginTemp()
        self.search("外国人翻唱")
        self.libraryRow("外国人翻唱").tap()
        XCTAssertTrue(self.hittableButton("暂停").waitForExistence(timeout: 30))
        self.openPlayingPage()
        self.app.swipeRight()
        XCTAssertTrue(self.app.staticTexts["该歌曲没有视频"].waitForExistence(timeout: 10))
        self.shot("视频已删除")
        self.closeVideoAndLogout()
    }

    /// 点视频的控制按钮,控制按钮自动隐藏之后先点一下视频显示出来
    /// 视频播放时获取界面元素比较慢,控制按钮可能在找到之后点击之前自动隐藏,所以记下按钮位置按坐标点击
    /// - Parameter label: 按钮名称,为nil时只显示控制按钮
    private func tapVideoControl(_ label: String?) {
        let anyControl = self.app.buttons.matching(NSPredicate(format: "label IN %@", ["全屏", "退出全屏"])).firstMatch
        for _ in 0 ..< 3{
            if !anyControl.exists{
                self.app.otherElements["视频"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
                _ = anyControl.waitForExistence(timeout: 3)
            }
            guard let label else{
                return
            }
            let button = self.app.buttons[label]
            if button.exists{
                let frame = button.frame
                self.app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
                return
            }
        }
        XCTFail("没有找到视频控制按钮:" + (label ?? ""))
    }

    /// 等屏幕旋转完成,最多等6秒
    /// - Parameter landscape: true:等横屏 false:等竖屏
    private func waitLandscape(_ landscape: Bool) -> Bool {
        for _ in 0 ..< 12{
            if self.isLandscape == landscape{
                return true
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }

    /// 屏幕是否横向显示,窗口的frame不随方向变化,用截图的宽高判断
    private var isLandscape: Bool {
        let size = XCUIScreen.main.screenshot().image.size
        return size.width > size.height
    }

    /// 搜索曲库,播放歌曲,打开播放页并切换到视频页面,等视频开始播放
    private func openVideo(_ key: String, _ titlePrefix: String) {
        self.search(key)
        self.libraryRow(titlePrefix).tap()
        XCTAssertTrue(self.hittableButton("暂停").waitForExistence(timeout: 30))
        self.openPlayingPage()
        self.app.swipeRight()
        self.waitVideo()
        Thread.sleep(forTimeInterval: 3)
    }

    /// 离开视频页面,关闭播放页,退出登录
    private func closeVideoAndLogout() {
        self.app.swipeLeft()
        self.app.buttons["关闭"].tap()
        self.back()
        self.app.buttons["我的"].tap()
        self.logout()
    }

    /// 从首页搜索曲库
    private func search(_ key: String) {
        self.app.buttons["搜索歌曲、歌手"].tap()
        let searchField = self.app.textFields["搜索歌曲、歌手"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.typeText(key + "\n")
    }

    /// 曲库搜索结果里标题开头相同的那一行(采集平台的结果带YT标签)
    private func libraryRow(_ titlePrefix: String) -> XCUIElement {
        let title = NSPredicate(format: "label BEGINSWITH %@", titlePrefix)
        let rows = self.app.cells.containing(title).allElementsBoundByIndex
        let row = rows.first{ !$0.staticTexts["YT"].exists } ?? self.app.cells.containing(title).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        return row.staticTexts.matching(title).firstMatch
    }

    /// 点击迷你播放条打开播放页
    private func openPlayingPage() {
        self.app.buttons["播放列表"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: -4, dy: 0.5)).tap()
        XCTAssertTrue(self.app.buttons["关闭"].waitForExistence(timeout: 5))
    }

    /// 等待视频开始播放
    private func waitVideo(timeout: TimeInterval = 60, file: StaticString = #filePath, line: UInt = #line) {
        //开始播放之后才显示视频播放控件,不允许下载视频时没有下载按钮,不能用下载按钮判断
        let video = self.app.otherElements["视频"].firstMatch
        if !video.waitForExistence(timeout: timeout){
            self.shot("视频没有开始播放")
            XCTFail("视频没有开始播放", file: file, line: line)
        }
    }
}
