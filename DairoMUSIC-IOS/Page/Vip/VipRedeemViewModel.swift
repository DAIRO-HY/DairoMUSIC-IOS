//
//  VipRedeemViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/14.
//

import SwiftUI
import DairoUI_IOS

class VipRedeemViewModel: ObservableObject {

    /// 卡号的位数
    static let CARD_NO_LENGTH = 16

    /// 卡号,每4位一组用空格隔开显示
    @Published var cardNo = ""{
        didSet{
            let formatted = VipRedeemViewModel.formatCardNo(self.cardNo)
            if formatted != self.cardNo{
                self.cardNo = formatted
            }
        }
    }

    /// 卡密,自动转成大写
    @Published var cardPwd = ""{
        didSet{
            let formatted = self.cardPwd.uppercased().filter{ !$0.isWhitespace }
            if formatted != self.cardPwd{
                self.cardPwd = formatted
            }
        }
    }

    /// 已经是永久VIP时,需要会员确认的提示
    @Published var confirmMessage: String?

    /// 卡号只保留数字,最多16位,每4位一组
    private static func formatCardNo(_ text: String) -> String {
        let digits = String(text.filter{ $0.isASCII && $0.isNumber }.prefix(VipRedeemViewModel.CARD_NO_LENGTH))
        var result = ""
        for (i, c) in digits.enumerated(){
            if i > 0 && i % 4 == 0{
                result.append(" ")
            }
            result.append(c)
        }
        return result
    }

    /// 兑换按钮点击事件
    func onRedeemClick() {
        if self.cardNo.filter({ $0.isNumber }).count != VipRedeemViewModel.CARD_NO_LENGTH{
            Toast.show("请输入16位卡号")
            return
        }
        if self.cardPwd.isEmpty{
            Toast.show("请输入卡密")
            return
        }
        self.redeem(confirm: false)
    }

    /// 会员确认之后再提交一次
    func onConfirmClick() {
        self.redeem(confirm: true)
    }

    /// 提交兑换
    private func redeem(confirm: Bool) {
        VipApi.redeem(cardNo: self.cardNo, cardPwd: self.cardPwd, confirm: confirm).send{ [weak self] result in
            guard let self else{
                return
            }
            if result.needConfirm{
                self.confirmMessage = result.message
                return
            }
            if let vip = result.vip{
                SettingShared.updateVip(vip)
            }
            self.cardNo = ""
            self.cardPwd = ""
            Toast.show(result.message)
        }
    }
}
