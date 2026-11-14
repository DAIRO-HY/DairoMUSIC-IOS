//
//  AccountListViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

class AccountListViewModel: ObservableObject {

    /// 记录当前要操作的索引
    var actionIndex = -1

    /// 当前已登录的账号列表
    @Published var accountList = [AccountInfo]()

    /// 获取当前操作的账号
    var actionItem: AccountInfo{
        return self.accountList[self.actionIndex]
    }

    init() {
        self.loadData()
    }

    /// 加载数据
    func loadData(){
        self.accountList = SettingStore.accountList
    }

    /// 删除账号点击事件
    func onDeleteClick(){
        let actionItem = self.actionItem
        self.accountList.removeAll{ $0.isSame(actionItem) }
        SettingStore.accountList = self.accountList
    }
}
