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

    /// 登录账号,有邮箱时是邮箱,只有用户名的会员是用户名,临时会员为空
    var account: String

    /// 显示的名字,邮箱或者临时会员的昵称
    var name: String

    /// 登录票据,退出登录之后为空;保存在钥匙串里,不保存到文件
    var token = ""

    /// 是否当前登录的账号
    var isCurrent: Bool  = false

    /// 保存到文件的字段,不包括票据
    private enum CodingKeys: String, CodingKey {
        case domain, serverId, userId, account, name, isCurrent
    }

    /// 是否同一个账号
    func isSame(_ other: AccountInfo) -> Bool {
        return self.serverId == other.serverId && self.userId == other.userId
    }

    /// 登录票据保存在钥匙串里的名字
    var tokenKey: String {
        return "TOKEN_\(self.serverId)_\(self.userId)"
    }
}
