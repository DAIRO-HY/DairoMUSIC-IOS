//
//  AccountInfo.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

///登录信息
struct AccountInfo : Codable,Hashable{

    /// 服务器地址
    var domain: String

    /// 服务器ID,同一个服务器换了地址之后依然不变
    var serverId: String

    /// 会员ID
    var userId: Int64

    /// 登录邮箱,临时会员为空
    var email: String

    /// 显示的名字,邮箱或者临时会员的昵称
    var name: String

    /// 登录票据,退出登录之后为空
    var token: String

    /// 是否当前登录的账号
    var isLogining: Bool  = false

    /// 是否同一个账号
    func isSame(_ other: AccountInfo) -> Bool {
        return self.serverId == other.serverId && self.userId == other.userId
    }
}
