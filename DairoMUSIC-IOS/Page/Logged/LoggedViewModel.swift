//
//  LoggedViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

class LoggedViewModel: ObservableObject {

    /// 记录当前要操作的索引
    var actionIndex = -1

    /// 当前已登录的账号列表
    @Published var loggedUserList = [AccountInfo]()

    /// 获取当前操作的账号
    var actionItem: AccountInfo{
        return self.loggedUserList[self.actionIndex]
    }

    init() {
        self.loadData()
    }

    /// 加载数据
    func loadData(){
        self.loggedUserList = SettingShared.loggedUserList
    }

    /// 删除账号点击事件
    func onDeleteClick(){
        let actionItem = self.actionItem
        self.loggedUserList.removeAll{ $0.isSame(actionItem) }
        SettingShared.loggedUserList = self.loggedUserList
    }
}
