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
    var token: String

    /// 是否当前登录的账号
    var isLogining: Bool  = false

    /// 是否同一个账号
    func isSame(_ other: AccountInfo) -> Bool {
        return self.serverId == other.serverId && self.userId == other.userId
    }

    /// 登录票据保存在钥匙串里的名字
    var tokenKey: String {
        return "TOKEN_\(self.serverId)_\(self.userId)"
    }
}

/// 写在扩展里,保留自动生成的成员初始化方法
extension AccountInfo {

    /// 以前只能用邮箱登录,保存的字段名是email;老版本的票据保存在文件里,读取时还要读出来移到钥匙串
    private enum CodingKeys: String, CodingKey {
        case domain, serverId, userId, account = "email", name, token, isLogining
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.domain = try container.decode(String.self, forKey: .domain)
        self.serverId = try container.decode(String.self, forKey: .serverId)
        self.userId = try container.decode(Int64.self, forKey: .userId)
        self.account = try container.decode(String.self, forKey: .account)
        self.name = try container.decode(String.self, forKey: .name)
        self.token = try container.decodeIfPresent(String.self, forKey: .token) ?? ""
        self.isLogining = try container.decodeIfPresent(Bool.self, forKey: .isLogining) ?? false
    }

    /// 不保存票据
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.domain, forKey: .domain)
        try container.encode(self.serverId, forKey: .serverId)
        try container.encode(self.userId, forKey: .userId)
        try container.encode(self.account, forKey: .account)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.isLogining, forKey: .isLogining)
    }
}
