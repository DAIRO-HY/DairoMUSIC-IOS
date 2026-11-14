//
//  SettingShared.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import Foundation
import DairoUI_IOS

/// 用户设置
enum SettingShared {
    /*----------------------------------------------------------------------------------*/

    /// 会员信息
    private static let _KEY_USER = "USER"

    /// 会员信息
    static var user: UserModel?{
        get{
            return LocalObjectUtil.read(UserModel.self, SettingShared._KEY_USER)
        }

        set{
            _ = LocalObjectUtil.write(newValue, SettingShared._KEY_USER)
            ServerConfig.shared.updateVip(newValue?.vip)
        }
    }

    /// 更新本地保存的VIP状态(兑换VIP之后)
    static func updateVip(_ vip: VipModel?) {
        guard var user = SettingShared.user else{
            return
        }
        user.vip = vip
        SettingShared.user = user
    }

    /// 后台刷新会员信息,不弹出加载等待框
    /// - Parameter silent: 失败时不提示(启动App、回到前台时刷新VIP状态)
    static func loadUserInBackground(silent: Bool = false, _ success: @escaping (_ user: UserModel) -> Void = { _ in }) {
        var request = UserApi.info().hide()
        if silent{
            request = request.fail{ _ in }.error{ _ in }
        }
        request.send{
            SettingShared.user = $0
            SettingShared.updateLoggedUser($0)
            success($0)
        }
    }

    /*----------------------------------------------------------------------------------*/

    /// 登录Token
    private static let KEY_TOKEN = "TOKEN"
    private static var mToken: String? = nil

    /// 登录Token
    static var token: String {
        get{
            if SettingShared.mToken == nil{
                SettingShared.mToken = UserDefaults.standard.string(forKey: KEY_TOKEN)
            }
            return SettingShared.mToken ?? ""
        }
        set{
            SettingShared.mToken = newValue;
            if newValue.isEmpty {
                UserDefaults.standard.removeObject(forKey: KEY_TOKEN)
                return;
            }
            UserDefaults.standard.set(newValue, forKey: KEY_TOKEN)
        }
    }

    /*----------------------------------------------------------------------------------*/

    /// 当前服务器地址
    private static let _DOMAIN = "DOMAIN";
    private static var _domain: String?

    static var domainNotNull: String{
        return SettingShared.domain ?? ""
    }

    static var domain: String?{
        get {
            if SettingShared._domain == nil{
                SettingShared._domain = UserDefaults.standard.string(forKey: SettingShared._DOMAIN)
            }
            return SettingShared._domain;
        }

        set{
            SettingShared._domain = newValue;
            if newValue == nil {
                UserDefaults.standard.removeObject(forKey: SettingShared._DOMAIN)
                return;
            }
            UserDefaults.standard.set(newValue, forKey: SettingShared._DOMAIN)
        }
    }

    /// 服务器ID
    private static let KEY_SERVER_ID = "SERVER_ID"

    /// 服务器ID,作为SDK的缓存命名空间,服务器换了地址之后缓存依然有效
    static var serverId: String {
        get{
            return UserDefaults.standard.string(forKey: KEY_SERVER_ID) ?? ""
        }
        set{
            UserDefaults.standard.set(newValue, forKey: KEY_SERVER_ID)
        }
    }

    /*----------------------------------------------------------------------------------*/

    /// 登录过的账号列表
    static var loggedUserList: [AccountInfo]{
        get{
            return LocalObjectUtil.read([AccountInfo].self, "loggedUserList") ??  [AccountInfo]()
        }

        set{
            _ = LocalObjectUtil.write(newValue, "loggedUserList")
        }
    }

    /// 当前登录的账号
    static var loggedUser: AccountInfo? {
        return SettingShared.loggedUserList.first{ $0.isLogining }
    }

    /// 是否登录
    static var isLogin: Bool{ !SettingShared.token.isEmpty && !SettingShared.serverId.isEmpty }

    /// 获取当前账号的本地对象缓存名,不同账号的缓存互相隔离,没有登录时返回nil,此时不使用缓存
    static func accountObjectName(_ name: String) -> String? {
        guard SettingShared.isLogin, let account = SettingShared.loggedUser else{
            return nil
        }
        let folder = "account_cache/\(account.serverId)_\(account.userId)"
        _ = FileUtil.mkdirs(LocalObjectUtil.mFolder + "/" + folder)
        return folder + "/" + name
    }

    /// 退出登录
    static func logout() {
        PlayerManager.shared.stop()
        var logined = SettingShared.loggedUserList
        for i in 0 ..< logined.count{
            if logined[i].isLogining{
                logined[i].token = ""
            }
            logined[i].isLogining = false
        }
        SettingShared.loggedUserList = logined
        SettingShared.token = ""
        SettingShared.user = nil
        SettingShared.onAccountChange()
    }

    /// 退出登录,并跳转到登录页面,自动填写当前账号的信息
    static func toLoginPage() {
        let account = SettingShared.loggedUser
        SettingShared.logout()
        if let account{
            LoginPage(LoginViewModel(domain: account.domain, email: account.email)).relaunch()
        } else {
            ServerPage().relaunch()
        }
    }

    /// 获取服务器的公开配置,同时确认是否DairoMUSIC服务器
    static func checkServer(domain: String, success: @escaping (_ config: ConfigModel) -> Void) {
        CommonApi.config().domain(domain).fail{
            Toast.show($0.msg ?? "获取服务器信息失败,请确认是否DairoMUSIC服务器")
        }.send(success)
    }
    
    /// 登录,登录类接口都返回票据和会员信息,先确认服务器地址可用再登录,登录成功之后才切换服务器
    /// - Parameter domain: 服务器地址
    /// - Parameter editIndex: 编辑账号时,账号在已登录列表里的序号,登录成功之后替换这个账号
    /// - Parameter request: 登录请求
    static func login(domain: String, editIndex: Int? = nil, request: @escaping () -> ApiHttp<LoginModel>, success: @escaping () -> Void) {
        SettingShared.checkServer(domain: domain){ config in
            request().domain(domain).fail{
                Toast.show($0.msg ?? "登录失败")
            }.send{ loginInfo in//登录成功
                PlayerManager.shared.stop()
                let user = loginInfo.user
                let account = AccountInfo(domain: domain, serverId: config.serverId, userId: user.id, email: user.email ?? "",
                                          name: SettingShared.accountName(user), token: loginInfo.token, isLogining: true)
                SettingShared.loggedUserList = SettingShared.addLoggedUser(account, editIndex: editIndex)
                SettingShared.domain = domain
                SettingShared.serverId = config.serverId
                SettingShared.token = loginInfo.token
                SettingShared.user = user
                SettingShared.onAccountChange()
                success()
            }
        }
    }

    /// 将登录成功的账号保存到已登录列表,同一个服务器的同一个会员只保留一条,编辑时保持账号原来的位置
    private static func addLoggedUser(_ account: AccountInfo, editIndex: Int?) -> [AccountInfo] {
        var list = SettingShared.loggedUserList
        list.indices.forEach{ list[$0].isLogining = false }
        guard let editIndex, list.indices.contains(editIndex) else{
            list.removeAll{ $0.isSame(account) }
            list.append(account)
            return list
        }
        list[editIndex] = account
        return list.enumerated().filter{ $0.offset == editIndex || !$0.element.isSame(account) }.map{ $0.element }
    }

    /// 切换到已经登录过的账号,票据失效时会跳转到登录页面
    static func switchAccount(_ account: AccountInfo, success: @escaping () -> Void) {
        let oldDomain = SettingShared.domain
        let oldToken = SettingShared.token
        let oldServerId = SettingShared.serverId
        let oldLoggedUserList = SettingShared.loggedUserList
        let onFail = { (msg: String) in
            SettingShared.domain = oldDomain
            SettingShared.loggedUserList = oldLoggedUserList
            SettingShared.serverId = oldServerId
            SettingShared.token = oldToken
            Toast.show(msg)
        }
        var loggedUserList = oldLoggedUserList
        loggedUserList.indices.forEach{
            loggedUserList[$0].isLogining = loggedUserList[$0].isSame(account)
        }
        SettingShared.domain = account.domain
        SettingShared.loggedUserList = loggedUserList
        SettingShared.serverId = account.serverId
        SettingShared.token = account.token
        UserApi.info().error(block: onFail).fail{
            onFail($0.msg ?? "切换账号失败")
        }.send{
            PlayerManager.shared.stop()
            SettingShared.user = $0
            SettingShared.updateLoggedUser($0)
            SettingShared.onAccountChange()
            success()
        }
    }

    /// 会员信息变化之后,更新已登录列表里显示的名字,临时会员绑定邮箱之后也会更新邮箱
    private static func updateLoggedUser(_ user: UserModel) {
        var list = SettingShared.loggedUserList
        guard let index = list.firstIndex(where: { $0.isLogining }) else{
            return
        }
        list[index].email = user.email ?? ""
        list[index].name = SettingShared.accountName(user)
        SettingShared.loggedUserList = list
    }

    /// 账号显示的名字,临时会员没有邮箱时显示昵称
    private static func accountName(_ user: UserModel) -> String {
        if let email = user.email, !email.isEmpty{
            return email
        }
        return user.nick ?? "临时会员"
    }

    /// 账号变化之后,清空内存里上一个账号的数据,加载新账号的播放列表
    private static func onAccountChange() {
        FavoriteShared.clearMemory()
        MusicShared.clearMemory()
        PlayerManager.shared.restore()

        //提交新账号上次没有提交成功的播放记录
        PlayCountUtil.submit()
    }

    /*----------------------------------------------------------------------------------*/

    /// 无损音质的比特率
    static let BIT_RATE_LOSSLESS = 999

    /// 标准音质的比特率,非VIP只能听标准音质
    static let BIT_RATE_STANDARD = 128

    /// 目标音质,返回不超过这个音质的最高音质文件
    static var bitRate: Int{
        get{
            let value = UserDefaults.standard.integer(forKey: "BIT_RATE")
            return value == 0 ? 320 : value
        }
        set{
            UserDefaults.standard.set(newValue, forKey: "BIT_RATE")
        }
    }

    /*----------------------------------------------------------------------------------*/

    /// 视频清晰度:原画
    static let VIDEO_QUALITY_ORIGINAL = 1

    /// 视频清晰度:流畅
    static let VIDEO_QUALITY_SMOOTH = 2

    /// 视频清晰度,记住上次的选择,默认流畅
    static var videoQuality: Int{
        get{
            let value = UserDefaults.standard.integer(forKey: "VIDEO_QUALITY")
            return value == 0 ? SettingShared.VIDEO_QUALITY_SMOOTH : value
        }
        set{
            UserDefaults.standard.set(newValue, forKey: "VIDEO_QUALITY")
        }
    }

    /// 播放页左右滑动的引导是否已经显示过,UI测试时通过启动参数跳过引导
    static var playingGuideShown: Bool{
        get{ UserDefaults.standard.bool(forKey: "PLAYING_GUIDE_SHOWN") }
        set{ UserDefaults.standard.set(newValue, forKey: "PLAYING_GUIDE_SHOWN") }
    }

    /// 音乐边播边缓存的设置名,页面上用AppStorage绑定
    static let KEY_MUSIC_CACHE = "MUSIC_CACHE"

    /// 音乐是否边播边缓存,默认开启;关闭时没有缓存的歌曲直接在线播放
    static var musicCache: Bool{
        return UserDefaults.standard.object(forKey: SettingShared.KEY_MUSIC_CACHE) as? Bool ?? true
    }

    /// 视频边播边缓存的设置名,页面上用AppStorage绑定
    static let KEY_VIDEO_CACHE = "VIDEO_CACHE"

    /// 视频是否边播边缓存,默认在线播放
    static var videoCache: Bool{
        return UserDefaults.standard.bool(forKey: SettingShared.KEY_VIDEO_CACHE)
    }

    /*----------------------------------------------------------------------------------*/

    /// 同时缓存文件数,0表示没有设置过
    static var fileSdkMaxCachingCount: Int{
        get{ UserDefaults.standard.integer(forKey: "FILE_SDK_MAX_CACHING_COUNT") }
        set{ UserDefaults.standard.set(newValue, forKey: "FILE_SDK_MAX_CACHING_COUNT") }
    }

    /// 缓存文件保存天数,nil表示没有设置过,0表示永久
    static var fileSdkCacheExpireDays: Int?{
        get{ UserDefaults.standard.object(forKey: "FILE_SDK_CACHE_EXPIRE_DAYS") as? Int }
        set{ UserDefaults.standard.set(newValue, forKey: "FILE_SDK_CACHE_EXPIRE_DAYS") }
    }

    /// 缓存容量上限(MB),0表示没有设置过
    static var fileSdkMaxCacheSize: Int{
        get{ UserDefaults.standard.integer(forKey: "FILE_SDK_MAX_CACHE_SIZE") }
        set{ UserDefaults.standard.set(newValue, forKey: "FILE_SDK_MAX_CACHE_SIZE") }
    }
    /*----------------------------------------------------------------------------------*/
}
