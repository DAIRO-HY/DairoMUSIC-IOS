//
//  VipModel++.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/14.
//

import Foundation

extension VipModel {

    /// VIP状态的说明:永久、到期日期、已到期、未开通
    var statusText: String {
        if self.forever{
            return "永久"
        }
        if self.expireTime == 0{
            return "未开通"
        }
        if !self.isVip{
            return "已到期"
        }
        return self.expireDateText + "到期"
    }

    /// 到期日期
    var expireDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(self.expireTime) / 1000))
    }
}
